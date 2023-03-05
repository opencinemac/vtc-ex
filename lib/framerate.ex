defmodule Vtc.Framerate do
  @moduledoc """
  The rate at which a video file frames are played back.

  Framerate is measured in frames-per-second (24/1 = 24 frames-per-second).
  """

  use Ratio, comparison: true

  alias Vtc.Utils.Rational

  @enforce_keys [:playback, :ntsc]
  defstruct [:playback, :ntsc]

  @typedoc """
  Enum of `Ntsc` types.

  # Values

  - `:None`: Not an NTSC value
  - `:NonDrop` A non-drop NTSC value.
  - `:Drop` A drop-frame ntsc value.

  For more information on NTSC standards and framerate conventions, see
  [Frame.io's](frame.io)
  [blogpost](https://blog.frame.io/2017/07/17/timecode-and-frame-rates) on the subject.
  """
  @type ntsc() :: :None | :NonDrop | :Drop

  @typedoc """
  Type of `Framerate`

  # Fields

  - `:playback`: The rational representation of the real-world playback speed as a
    fraction in frames-per-second.

  - `:ntsc`: Atom representing which, if any, NTSC convention this framerate adheres to.
  """
  @type t :: %__MODULE__{playback: Rational.t(), ntsc: ntsc()}

  @doc """
  The rational representation of the timecode timebase speed as a fraction in
  frames-per-second.
  """
  @spec timebase(t()) :: Rational.t()
  def timebase(%__MODULE__{ntsc: :None} = framerate), do: framerate.playback
  def timebase(framerate), do: Rational.round(framerate.playback)

  defmodule ParseError do
    @moduledoc """
    Exception returned when a framerate cannot be parsed.
    """
    defexception [:reason]

    @typedoc """
    Type of `ParseError`

    # Fields

    - `:reason`: The reason the error occurred must be one of the following:

      - `:bad_drop_rate`: Returned when the playback speed of a framerate with an ntsc
        value of :Drop is not divisible by 3000/1001 (29.97), for more on why drop-frame
        framerates must be a multiple of 29.97, see:
        https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/

      - `:invalid_ntsc`: Returned when the ntsc value is not one of the allowed atom
        values.

      - `:unrecognized_format`: Returned when a string value is not a recognized format.

      - `:imprecise` - Returned when a float was passed with an NTSC value of :None.
        Without the ability to round to the nearest valid NTSC value, floats are not
        precise enough to build an arbitrary framerate.
    """
    @type t() :: %__MODULE__{
            reason: :bad_drop_rate | :invalid_ntsc | :unrecognized_format | :imprecise
          }

    @doc """
    Returns a message for the error reason.
    """
    @spec message(t()) :: String.t()
    def message(%__MODULE__{reason: :bad_drop_rate}),
      do: "drop-frame rates must be divisible by 30000/1001"

    def message(%__MODULE__{reason: :invalid_ntsc}),
      do: "ntsc is not a valid atom. must be :NonDrop, :Drop, or None"

    def message(%__MODULE__{reason: :unrecognized_format}),
      do: "framerate string format not recognized"

    def message(%__MODULE__{reason: :imprecise}),
      do: "floats are not precise enough to create a non-NTSC Framerate"
  end

  @typedoc """
  Type returned by `Framerate.new/2`

  `Framerate.new!/2` raises the error value instead.
  """
  @type parse_result() :: {:ok, t()} | {:error, ParseError.t()}

  @doc """
  Creates a new Framerate with a playback speed or timebase.

  # Arguments

  - **rate**: Either the playback rate or timebase. For NTSC framerates, the value will
    be rounded to the nearest correct value.

  - **ntsc**: Atom representing the which (or whether an) NTSC standard is being used.

  - **coerce_timebases?**: If `true`, then values such as `1/24` are assumed to be
    timebases and automatically converted to `24/1`.
  """
  @spec new(Rational.t() | float() | String.t(), ntsc(), boolean()) :: parse_result()
  def new(rate, ntsc, coerce_timebases? \\ true)

  def new(%Ratio{} = rate, ntsc, coerce_timebases?), do: new_core(rate, ntsc, coerce_timebases?)
  def new(rate, ntsc, _) when is_integer(rate), do: new_core(rate, ntsc, false)
  def new(rate, :None, _) when is_float(rate), do: {:error, %ParseError{reason: :imprecise}}

  def new(rate, ntsc, coerce_timebases?) when is_float(rate),
    do: rate |> Ratio.new(1.0) |> new_core(ntsc, coerce_timebases?)

  def new(rate, ntsc, coerce?) when is_binary(rate) do
    try_integer = fn -> rate |> String.to_integer() |> new(ntsc, coerce?) end
    try_float = fn -> rate |> String.to_float() |> new(ntsc, coerce?) end
    try_rational = fn -> parse_rational_string(rate, ntsc, coerce?) end

    [try_integer, try_float, try_rational]
    |> Stream.map(fn attempt ->
      try do
        attempt.()
      rescue
        ArgumentError -> :argument_error
      end
    end)
    |> Enum.reduce_while({:error, %ParseError{reason: :unrecognized_format}}, fn
      :argument_error, final_error -> {:cont, final_error}
      result, _ -> {:halt, result}
    end)
  end

  @doc """
  As `Framerate.new/2` but raises an error instead.
  """
  @spec new!(Rational.t() | float() | String.t(), ntsc()) :: t()
  def new!(rate, ntsc) do
    case new(rate, ntsc) do
      {:ok, framerate} -> framerate
      {:error, error} -> raise error
    end
  end

  # validates that a rate is a proper drop-frame framerate.
  @spec validate_drop(Ratio.t(), ntsc()) :: :ok | {:error, ParseError.t()}
  defp validate_drop(rate, ntsc) do
    # if this value does not go cleanly into 29.97, then it cannot be a drop-frame
    # value.
    cond do
      ntsc != :Drop ->
        :ok

      not is_integer(rate / Ratio.new(30_000, 1_001)) ->
        {:error, %ParseError{reason: :bad_drop_rate}}

      true ->
        :ok
    end
  end

  # The core parser used to parse a rational or integer rate value.
  @spec new_core(Rational.t(), ntsc(), boolean()) :: parse_result()
  defp new_core(rate, ntsc, coerce_timebases?) do
    # validate that our ntsc atom is one of the acceptable values.
    with :ok <- validate_ntsc(ntsc),
         rate <- coerce_timebases(rate, coerce_timebases?),
         rate <- coerce_ntsc_rate(rate, ntsc),
         :ok <- validate_drop(rate, ntsc) do
      {:ok, %__MODULE__{playback: rate, ntsc: ntsc}}
    end
  end

  # validates that the ntsc atom is one of our allowed values.
  @spec validate_ntsc(ntsc()) :: :ok | {:error, ParseError.t()}
  defp validate_ntsc(ntsc) when ntsc in [:Drop, :NonDrop, :None], do: :ok
  defp validate_ntsc(_), do: {:error, %ParseError{reason: :invalid_ntsc}}

  # coerces a rate to the closest proper NTSC playback rate.
  @spec coerce_ntsc_rate(Ratio.t(), ntsc()) :: Ratio.t()
  defp coerce_ntsc_rate(rate, ntsc) do
    if ntsc != :None and Ratio.denominator(rate) != 1001 do
      Rational.round(rate) * 1000 / 1001
    else
      rate
    end
  end

  @spec coerce_timebases(Rational.t(), boolean()) :: Rational.t()
  defp coerce_timebases(%Ratio{numerator: num, denominator: denom}, true)
       when Kernel.<(num, denom),
       do: Ratio.new(denom, num)

  defp coerce_timebases(rate, _), do: rate

  # parses a rational string value like '24/1'.
  @spec parse_rational_string(String.t(), ntsc(), boolean()) :: parse_result()
  defp parse_rational_string(str, ntsc, coerce_timebases?) do
    case String.split(str, "/") do
      [_, _] = split ->
        split
        |> Enum.map(&String.to_integer/1)
        |> Enum.sort(:desc)
        |> then(fn [num, denom] -> Ratio.new(num, denom) end)
        |> new_core(ntsc, coerce_timebases?)

      _ ->
        raise %ArgumentError{message: "not a fraction"}
    end
  end

  @doc """
  Returns true if the value represents and NTSC framerate.

  So will return true on `:NonDrop` and `:Drop`.
  """
  @spec ntsc?(t()) :: boolean()
  def ntsc?(%__MODULE__{ntsc: :None}), do: false
  def ntsc?(_), do: true

  @doc """
  Example returns:

  - 23.98 NTSC DF
  - 23.98 NTSC NDF
  - 23.98 fps
  """
  @spec to_string(t()) :: String.t()
  def to_string(rate) do
    float_str =
      Ratio.to_float(rate.playback)
      |> Float.round(2)
      |> Float.to_string()

    ntsc_string = if ntsc?(rate), do: " NTSC", else: " fps"

    drop_string =
      case rate.ntsc do
        :NonDrop -> " NDF"
        :Drop -> " DF"
        :None -> ""
      end

    "<#{float_str}#{ntsc_string}#{drop_string}>"
  end
end

defimpl Inspect, for: Vtc.Framerate do
  alias Vtc.Framerate

  @spec inspect(Framerate.t(), Elixir.Inspect.Opts.t()) :: String.t()
  def inspect(rate, _opts), do: Framerate.to_string(rate)
end

defimpl String.Chars, for: Vtc.Framerate do
  alias Vtc.Framerate

  @spec to_string(Framerate.t()) :: String.t()
  def to_string(term), do: Framerate.to_string(term)
end
