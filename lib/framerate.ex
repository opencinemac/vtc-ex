defmodule Vtc.Framerate do
  @moduledoc """
  The rate at which a video file frames are played back.

  Framerate is measured in frames-per-second (24/1 = 24 frames-per-second).

  ## Struct Fields

  - `playback`: The rational representation of the real-world playback speed as a
    fraction in frames-per-second.

  - `ntsc`: Atom representing which, if any, NTSC convention this framerate adheres to.

  ## Playback vs Timebase

  For NTSC timecode, the timebase always runs at a whole number of frames-per-second,
  which the timecode pretends in the playback speed of the Media. This makes timecode
  string calculations clean and accurate, rather than having partial frames at second
  and minute boundaries.

  So for footage shot at 23.98 NTSC, Timecode is caculated as-if the footage were
  running at 24fps, which `Vtc` calls the 'timebase'.
  """
  alias Vtc.Framerate.ParseError
  alias Vtc.Utils.DropFrame
  alias Vtc.Utils.Rational

  @enforce_keys [:playback, :ntsc]
  defstruct [:playback, :ntsc]

  @typedoc """
  Enum of `Ntsc` types.

  ## Values

  - `:non_drop` A non-drop NTSC value.
  - `:drop` A drop-frame ntsc value.
  - `nil`: Not an NTSC value

  For more information on NTSC standards and framerate conventions, see
  [Frame.io's](frame.io)
  [blogpost](https://blog.frame.io/2017/07/17/timecode-and-frame-rates) on the subject.
  """
  @type ntsc() :: :non_drop | :drop | nil

  @typedoc """
  Type of `Vtc.Framerate`
  """
  @type t :: %__MODULE__{playback: Ratio.t(), ntsc: ntsc()}

  @doc section: :inspect
  @doc """
  The rational representation of the timecode's 'logical speed'.

  Returned value is in frames-per-second.
  """
  @spec timebase(t()) :: Ratio.t()
  def timebase(%{ntsc: nil} = framerate), do: framerate.playback
  def timebase(framerate), do: framerate.playback |> Rational.round() |> Ratio.new()

  @doc section: :inspect
  @doc """
  Returns true if the value represents and NTSC framerate.

  Will return true on a Framerate with an `:ntsc` value of `:non_drop` and `:drop`.
  """
  @spec ntsc?(t()) :: boolean()
  def ntsc?(rate)
  def ntsc?(%{ntsc: nil}), do: false
  def ntsc?(_), do: true

  @typedoc """
  Type returned by `new/2`
  """
  @type parse_result() :: {:ok, t()} | {:error, ParseError.t()}

  @typedoc """
  Options for `new/2` and `new!/2`.
  """
  @type new_opts() :: [ntsc: ntsc(), invert?: boolean()]

  @doc section: :parse
  @doc """
  Creates a new Framerate with a playback speed or timebase.

  ## Arguments

  - `rate`: Either the playback rate or timebase. For NTSC framerates, the value will
    be rounded to the nearest correct value.

  ## Options

  - `ntsc`: Atom representing the which (or whether an) NTSC standard is being used.
    Default: `:non-drop`.

  - `invert?`: If `true`, the resulting rational `rate` value will be flipped so that
    `1/24`  becomes `24/1`. This can be helpeful when you are parsing a rate given in
    seconds-per-frame rather than frames-per-second. Default: `false`.

  > #### Float Precision {: .warning}
  >
  > Only floats representing a whole number can be passed for non-NTSC rates, as there
  > is no fully precise way to convert fractional floats to rational values.
  """
  @spec new(Ratio.t() | number() | String.t(), new_opts()) :: parse_result()
  def new(rate, opts \\ [])

  def new(rate, opts) when is_binary(rate) do
    # for binaries we need to try to match integer, float, and rational string
    # representations
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

  # validates that a rate is a proper drop-frame framerate.
  @spec validate_drop(Ratio.t(), ntsc()) :: :ok | {:error, ParseError.t()}
  defp validate_drop(rate, :drop) do
    case DropFrame.drop_allowed?(rate) do
      true -> :ok
      false -> {:error, %ParseError{reason: :bad_drop_rate}}
    end
  end

  defp validate_drop(_, _), do: :ok

  # The core parser used to parse a rational or integer rate value.
  @spec new_core(Ratio.t() | number(), new_opts()) :: parse_result()
  defp new_core(rate, opts) do
    ntsc = Keyword.get(opts, :ntsc, :non_drop)
    invert? = Keyword.get(opts, :invert, false)

    # validate that our ntsc atom is one of the acceptable values.
    with :ok <- validate_float(rate, ntsc),
         :ok <- validate_ntsc(ntsc),
         rate = Ratio.new(rate),
         rate = if(invert?, do: Ratio.new(rate.denominator, rate.numerator), else: rate),
         rate <- coerce_ntsc_rate(rate, ntsc),
         :ok <- validate_drop(rate, ntsc) do
      {:ok, %__MODULE__{playback: rate, ntsc: ntsc}}
    end
  end

  @spec validate_float(Ratio.t() | number(), ntsc()) :: :ok | {:error, ParseError.t()}
  defp validate_float(value, ntsc) when is_float(value) do
    if ntsc == nil and floor(value) != value do
      {:error, %ParseError{reason: :imprecise}}
    else
      :ok
    end
  end

  defp validate_float(_, _), do: :ok

  # validates that the ntsc atom is one of our allowed values.
  @spec validate_ntsc(ntsc()) :: :ok | {:error, ParseError.t()}
  defp validate_ntsc(ntsc) when ntsc in [:drop, :non_drop, nil], do: :ok
  defp validate_ntsc(_), do: {:error, %ParseError{reason: :invalid_ntsc}}

  # coerces a rate to the closest proper NTSC playback rate.
  @spec coerce_ntsc_rate(Ratio.t(), ntsc()) :: Ratio.t()
  defp coerce_ntsc_rate(rate, nil), do: rate
  defp coerce_ntsc_rate(%Ratio{denominator: 1001} = rate, _), do: rate
  defp coerce_ntsc_rate(rate, _), do: rate |> Rational.round() |> Ratio.new() |> Ratio.mult(Ratio.new(1000, 1001))
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
