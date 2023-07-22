defmodule Vtc.Framerate do
  @moduledoc """
  The rate at which a video file frames are played back, measured in frames-per-second
  (24/1 = 24 frames-per-second). For more on framerate and why Vtc chooses to represent
  it as a rational number, see [NTSC: Framerate vs timebase](framerate_vs_timebase.html)
  and [The Rational Rationale](the_rational_rationale.html)

  ## Struct Fields

  - `playback`: The rational representation of the real-world playback speed as a
    fraction in frames-per-second.

  - `ntsc`: Atom representing which, if any, NTSC convention this framerate adheres to.

  ## Using as an Ecto Type

  See [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`) for information on how to use
  `Framerate` in your postgres database as a native type.
  """
  use Vtc.Ecto.Postgres.Utils

  alias Vtc.Ecto.Postgres.PgFramerate
  alias Vtc.Framerate.ParseError
  alias Vtc.Utils.DropFrame
  alias Vtc.Utils.Rational

  @enforce_keys [:playback, :ntsc]
  defstruct [:playback, :ntsc]

  # For use in functions that must validate non-nil NTSC types.
  @valid_ntsc [:non_drop, :drop]

  @typedoc """
  Enum of `Ntsc` types.

  ## Values

  - `:non_drop` A non-drop NTSC value.
  - `:drop` A drop-frame ntsc value.
  - `nil`: Not an NTSC value

  For more information on NTSC standards and framerate conventions, see
  [Frame.io's](frame.io)
  [blog post](https://blog.frame.io/2017/07/17/timecode-and-frame-rates) on the subject.
  """
  @type ntsc() :: :non_drop | :drop | nil

  @typedoc """
  Type of [Framerate](`Vtc.Framerate`)
  """
  @type t() :: %__MODULE__{playback: Ratio.t(), ntsc: ntsc()}

  @doc section: :inspect
  @doc """
  The rational representation of the SMPTE timecode's 'logical speed'. For more on
  timebase and it's relationship to framerate, see:
  [NTSC: Framerate vs timebase](framerate_vs_timebase.html).

  Returned value is in frames-per-second.
  """
  @spec smpte_timebase(t()) :: Ratio.t()
  def smpte_timebase(%{ntsc: nil} = framerate), do: framerate.playback
  def smpte_timebase(framerate), do: framerate.playback |> Rational.round() |> Ratio.new()

  @doc section: :inspect
  @doc """
  Returns true if the value represents and NTSC framerate.

  Will return true on a Framerate with an `:ntsc` value of `:non_drop` and `:drop`.
  """
  @spec ntsc?(t()) :: boolean()
  def ntsc?(rate)
  def ntsc?(%{ntsc: ntsc}) when ntsc in @valid_ntsc, do: true
  def ntsc?(_), do: false

  @typedoc """
  Type returned by `new/2`
  """
  @type parse_result() :: {:ok, t()} | {:error, ParseError.t()}

  @typedoc """
  Type for `new/2` `coerce_ntsc?` option.
  """
  @type new_opt_coerce_ntsc?() :: boolean() | :if_trunc

  @typedoc """
  Options for `new/2` and `new!/2`.
  """
  @type new_opts() :: [
          ntsc: ntsc(),
          coerce_ntsc?: new_opt_coerce_ntsc?(),
          allow_float?: boolean(),
          invert?: boolean()
        ]

  @doc section: :parse
  @doc """
  Creates a new Framerate with a playback speed or timebase.

  ## Arguments

  - `rate`: Either the playback rate or timebase. For NTSC framerates, the value will
    be rounded to the nearest correct value.

  ## Options

  - `ntsc`: Atom representing the which (or whether an) NTSC standard is being used.
    Default: `nil`.

  - `coerce_ntsc?`: If and how to coerce values to the nearest NTSC value.
    Default: `false`

    - `true`: If `ntsc` is non-nil, values will be coerced to the
      nearest valid NTSC rate. So `24` would be coerced to `24000/1001`, as would
      `23.98`. This option must be set to true when `ntsc` is non-nil and a float is
      passed.

    - `false`: Do not coerce value. Passed value must conform exactly to a valid NTSC
      framerate.

    - `:if_trunc`: Will coerce value to a valid NTSC rate using the `ntsc` opt value
      *if* the below criteria are met. If the criteria are not met, the value will be
      parsed *as-is* with `ntsc` set to `nil`:

      - The incoming value is a float, with two or more significant digits that match
        the truncated+rounded form. So `23.98` and `23.976` would be coerced to
        `24000/1001` but `23.99` and `23.96` would both be left as-is.

      - The incoming value is a Rational, and precisely represents a valid NTSC
        framerate.

      - The incoming value is a Rational, that when cast to float, matches the above
        criteria.

      - The incoming value is a string representation of any of the above.

    - `allow_fractional_float?`: If `true`, will allow non-integer float values to be
      converted to Rational values when parsing framerates. Can be combined with
      `:if_trunc` to parse floating point values, coercing to NTSC if it appears to be
      an abbreviated NTSC value.

  - `invert?`: If `true`, the resulting rational `rate` value will be flipped so that
    `1/24`  becomes `24/1`. This can be helpful when you are parsing a rate given in
    seconds-per-frame rather than frames-per-second. Default: `false`.
  """
  @spec new(Ratio.t() | number() | String.t(), new_opts()) :: parse_result()
  def new(rate, opts \\ [])

  # for binaries we need to try to match integer, float, and rational string
  # representations
  def new(rate, opts) when is_binary(rate) do
    parsers = [
      &Integer.parse/1,
      &Float.parse/1,
      &parse_rational_string/1
    ]

    parsers
    |> Stream.map(fn parser -> parser.(rate) end)
    |> Enum.find_value(:error, fn
      {parsed, ""} -> parsed
      _ -> false
    end)
    |> then(fn
      :error -> {:error, %ParseError{reason: :unrecognized_format}}
      value -> new(value, opts)
    end)
  end

  def new(rate, opts), do: new_core(rate, opts)

  @doc section: :parse
  @doc """
  As `new/2` but raises an error instead.
  """
  @spec new!(Ratio.t() | number() | String.t(), new_opts()) :: t()
  def new!(rate, opts \\ []) do
    case new(rate, opts) do
      {:ok, framerate} -> framerate
      {:error, error} -> raise error
    end
  end

  # Parses a rational string value like '24/1'. Conforms to the same API as
  # `Integer.parse/1` and `Float.parse/1`.
  @spec parse_rational_string(String.t()) :: {Ratio.t(), String.t()} | :error
  defp parse_rational_string(binary) do
    case String.split(binary, "/") do
      [_, _] = split ->
        split
        |> Enum.map(&String.to_integer/1)
        |> then(fn [x, y] -> {Ratio.new(x, y), ""} end)

      _ ->
        :error
    end
  end

  # The core parser used to parse a rational or integer rate value.
  @spec new_core(Ratio.t() | number(), new_opts()) :: parse_result()
  defp new_core(input, opts) do
    ntsc = Keyword.get(opts, :ntsc, nil)
    invert? = Keyword.get(opts, :invert, false)
    coerce_ntsc? = Keyword.get(opts, :coerce_ntsc?, false)

    with :ok <- validate_ntsc(ntsc),
         :ok <- validate_coerce_ntsc_opts(ntsc, coerce_ntsc?),
         :ok <- validate_float(input, ntsc, coerce_ntsc?),
         rate = Ratio.new(input),
         :ok <- validate_positive(rate),
         rate = invert(rate, invert?),
         {:ok, rate, ntsc} <- coerce_ntsc_rate(rate, input, ntsc, coerce_ntsc?),
         :ok <- validate_drop(rate, ntsc) do
      {:ok, %__MODULE__{playback: rate, ntsc: ntsc}}
    end
  end

  @zero Ratio.new(0)

  # validates that the ntsc atom is one of our allowed values.
  @spec validate_ntsc(ntsc()) :: :ok | {:error, ParseError.t()}
  defp validate_ntsc(ntsc) when ntsc in [nil | @valid_ntsc], do: :ok
  defp validate_ntsc(_), do: {:error, %ParseError{reason: :invalid_ntsc}}

  # Validates that the `:coerce_ntsc?` and `:ntsc` opts are in a valid combination.
  @spec validate_coerce_ntsc_opts(ntsc(), new_opt_coerce_ntsc?()) :: :ok | {:error, ParseError.t()}
  defp validate_coerce_ntsc_opts(_, false), do: :ok

  defp validate_coerce_ntsc_opts(ntsc, coerce_ntsc?) when ntsc in @valid_ntsc and coerce_ntsc? in [:if_trunc, true],
    do: :ok

  defp validate_coerce_ntsc_opts(_, _), do: {:error, %ParseError{reason: :coerce_requires_ntsc}}

  # Validates that the float value can be reliably parsed given the `:ntsc` and
  # `coerce_ntsc?` opts.
  @spec validate_float(Ratio.t() | number(), ntsc(), new_opt_coerce_ntsc?()) :: :ok | {:error, ParseError.t()}
  defp validate_float(value, ntsc, _) when not is_float(value) or ntsc in @valid_ntsc, do: :ok
  defp validate_float(value, nil, _) when floor(value) == value, do: :ok
  defp validate_float(_, _, coerce_ntsc?) when coerce_ntsc? in [true, :if_trunc], do: :ok
  defp validate_float(_, _, _), do: {:error, %ParseError{reason: :imprecise_float}}

  # Validates that the rate is positive.
  @spec validate_positive(Ratio.t()) :: :ok | {:error, ParseError.t()}
  defp validate_positive(rate) do
    if Ratio.gt?(rate, @zero) do
      :ok
    else
      {:error, %ParseError{reason: :non_positive}}
    end
  end

  # Inverts the numerator and denominator of the rate if `invert` option was passed.
  @spec invert(Ratio.t(), boolean()) :: Ratio.t()
  defp invert(rate_rational, true), do: Ratio.new(rate_rational.denominator, rate_rational.numerator)
  defp invert(rate_rational, false), do: rate_rational

  # coerces a rate to the closest proper NTSC playback rate if the option is set.
  @spec coerce_ntsc_rate(
          Ratio.t(),
          Ratio.t() | number(),
          ntsc(),
          new_opt_coerce_ntsc?()
        ) :: {:ok, Ratio.t(), ntsc() | nil} | {:error, ParseError.t()}
  defp coerce_ntsc_rate(rate, _, nil, false), do: {:ok, rate, nil}

  defp coerce_ntsc_rate(rate, input, ntsc, coerce?) when coerce? in [true, :if_trunc] do
    rate_coerced = rate |> Rational.round() |> Ratio.new() |> Ratio.mult(Ratio.new(1000, 1001))

    return_coerced? =
      cond do
        coerce? == true -> true
        is_struct(input, Ratio) -> input == rate_coerced or coerce_close_float?(Ratio.to_float(input), rate_coerced)
        is_integer(input) -> false
        is_float(input) -> coerce_close_float?(input, rate_coerced)
      end

    cond do
      return_coerced? -> {:ok, rate_coerced, ntsc}
      coerce? == :if_trunc -> {:ok, rate, nil}
      true -> {:error, %ParseError{reason: :invalid_ntsc_rate}}
    end
  end

  defp coerce_ntsc_rate(rate, _, ntsc, false) do
    whole_frame = Rational.round(rate)

    if Ratio.new(whole_frame * 1000, 1001) == rate do
      {:ok, rate, ntsc}
    else
      {:error, %ParseError{reason: :invalid_ntsc_rate}}
    end
  end

  # Checks if a float is close enough to a valid NTSC representation to be coerced when
  # `:coerce_ntsc?` is set to `:if_trunc`.
  @spec coerce_close_float?(float(), Ratio.t()) :: boolean()
  defp coerce_close_float?(input, rate_coerced) do
    float_str = Float.to_string(input)

    [_, digits] = String.split(float_str, ".")
    digit_count = String.length(digits)

    with true <- digit_count > 1 do
      coerced_float = rate_coerced.numerator / rate_coerced.denominator
      expected_string = coerced_float |> Float.round(digit_count) |> Float.to_string()
      float_str == expected_string
    end
  end

  # validates that a rate is a proper drop-frame framerate.
  @spec validate_drop(Ratio.t(), ntsc()) :: :ok | {:error, ParseError.t()}
  defp validate_drop(rate, :drop) do
    if DropFrame.drop_allowed?(rate) do
      :ok
    else
      {:error, %ParseError{reason: :bad_drop_rate}}
    end
  end

  defp validate_drop(_, _), do: :ok

  when_pg_enabled do
    use Ecto.Type

    @doc section: :ecto_migrations
    @doc """
    The database type for [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`).

    Can be used in migrations as the fields type.
    """
    @impl Ecto.Type
    @spec type() :: atom()
    defdelegate type, to: PgFramerate

    @impl Ecto.Type
    @spec cast(t() | %{String.t() => any()} | %{atom() => any()}) :: {:ok, t()} | :error
    defdelegate cast(value), to: PgFramerate

    @impl Ecto.Type
    @spec load(PgFramerate.db_record()) :: {:ok, t()} | :error
    defdelegate load(value), to: PgFramerate

    @impl Ecto.Type
    @spec dump(t()) :: {:ok, PgFramerate.db_record()} | :error
    defdelegate dump(value), to: PgFramerate
  end
end

defimpl Inspect, for: Vtc.Framerate do
  alias Vtc.Framerate
  alias Vtc.Private.DropFrame
  alias Vtc.Utils.DropFrame

  @spec inspect(Framerate.t(), Elixir.Inspect.Opts.t()) :: String.t()
  def inspect(rate, _opts) do
    float_str =
      rate.playback
      |> Ratio.to_float()
      |> Float.round(2)
      |> Float.to_string()

    ntsc_string = if Framerate.ntsc?(rate), do: " NTSC", else: " fps"

    "<#{float_str}#{ntsc_string}#{drop_string(rate)}>"
  end

  # Returns the string for tagging a framerate as drop frame or non-drop frame when
  # the framerate could allow for both.
  @spec drop_string(Framerate.t()) :: String.t()
  defp drop_string(%{ntsc: nil}), do: ""
  defp drop_string(%{ntsc: :drop}), do: " DF"

  defp drop_string(%{ntsc: :non_drop} = rate) do
    if DropFrame.drop_allowed?(rate.playback) do
      " NDF"
    else
      ""
    end
  end
end

defimpl String.Chars, for: Vtc.Framerate do
  alias Vtc.Framerate

  @spec to_string(Framerate.t()) :: String.t()
  def to_string(term), do: inspect(term)
end
