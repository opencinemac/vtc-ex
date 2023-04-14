defmodule Vtc.Framerate do
  @moduledoc """
  The rate at which a video file frames are played back.

  Framerate is measured in frames-per-second (24/1 = 24 frames-per-second).

  ## Struct Fields

  - `playback`: The rational representation of the real-world playback speed as a
    fraction in frames-per-second.

  - `ntsc`: Atom representing which, if any, NTSC convention this framerate adheres to.
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
  Type of `Framerate`
  """
  @type t :: %__MODULE__{playback: Ratio.t(), ntsc: ntsc()}

  @doc """
  The rational representation of the timecode timebase speed as a fraction in
  frames-per-second.
  """
  @spec timebase(t()) :: Ratio.t()
  def timebase(%{ntsc: nil} = framerate), do: framerate.playback
  def timebase(framerate), do: framerate.playback |> Rational.round() |> Ratio.new()

  @typedoc """
  Type returned by `new/2`
  """
  @type parse_result() :: {:ok, t()} | {:error, ParseError.t()}

  @doc """
  Creates a new Framerate with a playback speed or timebase.

  ## Arguments

  - `rate`: Either the playback rate or timebase. For NTSC framerates, the value will
    be rounded to the nearest correct value.

  - `ntsc`: Atom representing the which (or whether an) NTSC standard is being used.

  - `coerce_seconds_per_frame?`: If `true`, then values such as `1/24` are assumed to be
    in seconds-per-frame format and automatically converted to `24/1`. Useful when you want
    to convert strings from multiple sources when some are seconds-per-frame and others are
    frames-per-second. NOTE: if you expect to be dealing with record-rate values for timelapse
    use at your own risk!

  NOTE: Floats cannot be passed if the rate is not NTSC and the value is not a while
  number, as there is no way to know the precise time do to floating-point errors.
  """
  @spec new(Ratio.t() | number() | String.t(), ntsc(), boolean()) :: parse_result()
  def new(rate, ntsc, coerce_seconds_per_frame? \\ true)

  def new(rate, nil, _) when is_float(rate) and rate != Kernel.floor(rate), do: {:error, %ParseError{reason: :imprecise}}

  def new(rate, ntsc, coerce?) when is_float(rate) or is_integer(rate) or is_struct(rate, Ratio),
    do: rate |> Ratio.new() |> new_core(ntsc, coerce?)

  def new(rate, ntsc, coerce?) when is_binary(rate) do
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
      value -> new(value, ntsc, coerce?)
    end)
  end

  @doc """
  As `new/2` but raises an error instead.
  """
  @spec new!(Ratio.t() | number() | String.t(), ntsc(), boolean()) :: t()
  def new!(rate, ntsc, coerce_seconds_per_frame? \\ true) do
    case new(rate, ntsc, coerce_seconds_per_frame?) do
      {:ok, framerate} -> framerate
      {:error, error} -> raise error
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
  @spec new_core(Ratio.t(), ntsc(), boolean()) :: parse_result()
  defp new_core(rate, ntsc, coerce_seconds_per_frame?) do
    # validate that our ntsc atom is one of the acceptable values.
    with :ok <- validate_ntsc(ntsc),
         rate <- coerce_seconds_per_frame(rate, coerce_seconds_per_frame?),
         rate <- coerce_ntsc_rate(rate, ntsc),
         :ok <- validate_drop(rate, ntsc) do
      {:ok, %__MODULE__{playback: rate, ntsc: ntsc}}
    end
  end

  # validates that the ntsc atom is one of our allowed values.
  @spec validate_ntsc(ntsc()) :: :ok | {:error, ParseError.t()}
  defp validate_ntsc(ntsc) when ntsc in [:drop, :non_drop, nil], do: :ok
  defp validate_ntsc(_), do: {:error, %ParseError{reason: :invalid_ntsc}}

  # coerces a rate to the closest proper NTSC playback rate.
  @spec coerce_ntsc_rate(Ratio.t(), ntsc()) :: Ratio.t()
  defp coerce_ntsc_rate(rate, nil), do: rate
  defp coerce_ntsc_rate(%Ratio{denominator: 1001} = rate, _), do: rate

  defp coerce_ntsc_rate(rate, _), do: rate |> Rational.round() |> Ratio.new() |> Ratio.mult(Ratio.new(1000, 1001))

  # Coerces timebase to framerate by flipping the numberator and denominator.
  @spec coerce_seconds_per_frame(Ratio.t(), boolean()) :: Ratio.t()
  defp coerce_seconds_per_frame(%{numerator: x, denominator: y}, true) when x < y, do: Ratio.new(y, x)

  defp coerce_seconds_per_frame(rate, _), do: rate

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

  @doc """
  Returns true if the value represents and NTSC framerate, therefore will return true
  on a Framerate with an `:ntsc` value of `:non_drop` and `:drop`.
  """
  @spec ntsc?(t()) :: boolean()
  def ntsc?(rate)
  def ntsc?(%{ntsc: nil}), do: false
  def ntsc?(_), do: true
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
