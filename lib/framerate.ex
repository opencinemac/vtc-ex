defmodule Vtc.Ntsc do
  @moduledoc """
  Enum-like atom value for the various NTSC standards.

  These values are used when constructing and inspecting `Vtc.Framerate` values.
  """

  @typedoc """
  Restricts the possible values of `Vtc.Ntsc`.

  # Values

  - `:None`: Not an NTSC value
  - `:NonDrop` A non-drop NTSC value.
  - `:Drop` A drop-frame ntsc value.

  For more information on NTSC standards and framerate conventions, see
  [Frame.io's](frame.io)
  [blogpost](https://blog.frame.io/2017/07/17/timecode-and-frame-rates) on the subject.
  """
  @type t :: :None | :NonDrop | :Drop

  @doc """
  Returns true if the value represents and NTSC framerate.

  So will return true on `:NonDrop` and `:Drop`.
  """
  @spec is_ntsc?(Vtc.Ntsc.t()) :: boolean
  def is_ntsc?(:None) do
    false
  end

  def is_ntsc?(ntsc) when is_atom(ntsc) do
    true
  end
end

defmodule Vtc.Framerate do
  @moduledoc """
  The rate at which a video file frames are played back.

  Framerate is measured in frames-per-second (24/1 = 24 frames-per-second).
  """

  use Ratio, comparison: true

  @enforce_keys [:playback, :ntsc]
  defstruct [:playback, :ntsc]

  @typedoc """
  Type of `Vtc.Framerate`

  # Fields

  - `:playback`: The rational representation of the real-world playback speed as a
    fraction in frames-per-second.

  - `:ntsc`: Atom representing which, if any, NTSC convention this framerate adheres to.
  """
  @type t :: %Vtc.Framerate{playback: Ratio.t(), ntsc: Vtc.Ntsc.t()}

  @doc """
  The rational representation of the timecode timebase speed as a fraction in
  frames-per-second.
  """
  @spec timebase(Vtc.Framerate.t()) :: Ratio.t()
  def timebase(framerate) do
    if framerate.ntsc == :None do
      framerate.playback
    else
      Private.Rat.round_ratio?(framerate.playback)
    end
  end

  defmodule ParseError do
    @moduledoc """
    Exception returned when a framerate cannot be parsed.
    """
    defexception [:reason]

    @typedoc """
    Type of `Vtc.Framerate.ParseError`

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
    @type t :: %ParseError{
            reason: :bad_drop_rate | :invalid_ntsc | :unrecognized_format | :imprecise
          }

    @doc """
    Returns a message for the error reason.
    """
    @spec message(Vtc.Framerate.ParseError.t()) :: String.t()
    def message(error) do
      case error.reason do
        :bad_drop_rate -> "drop-frame rates must be divisible by 30000/1001"
        :invalid_ntsc -> "ntsc is not a valid atom. must be :NonDrop, :Drop, or None"
        :unrecognized_format -> "framerate string format not recognized"
        :imprecise -> "floats are not precise enough to create a non-NTSC Framerate"
      end
    end
  end

  @typedoc """
  Type returned by `Vtc.Framerate.new/2`

  `Vtc.Framerate.new!/2` raises the error value instead.
  """
  @type parse_result :: {:ok, Vtc.Framerate.t()} | {:error, Vtc.Framerate.ParseError.t()}

  @doc """
  Creates a new Framerate with a playback speed or timebase.

  # Arguments

  - **rate**: Either the playback rate or timebase. For NTSC framerates, the value will
    be rounded to the nearest correct value.

  - **ntsc**: Atom representing the which (or whether an) NTSC standard is being used.
  """
  @spec new(Ratio.t(), Vtc.Ntsc.t()) :: parse_result
  def new(
        %Ratio{numerator: numerator, denominator: denominator} = rate,
        ntsc
      )
      when is_integer(numerator) and is_integer(denominator) do
    new_core(rate, ntsc)
  end

  @spec new(integer, Vtc.Ntsc.t()) :: parse_result
  def new(rate, ntsc) when is_integer(rate) do
    new_core(rate, ntsc)
  end

  @spec new(float, Vtc.Ntsc.t()) :: parse_result
  def new(rate, ntsc) when is_float(rate) do
    if ntsc == :None do
      {:error, %ParseError{reason: :imprecise}}
    else
      new(Ratio.new(rate, 1.0), ntsc)
    end
  end

  @spec new(String.t(), Vtc.Ntsc.t()) :: parse_result
  def new(rate, ntsc) when is_bitstring(rate) do
    result =
      try do
        new(String.to_integer(rate), ntsc)
      rescue
        ArgumentError -> nil
      end

    result =
      if result == nil do
        try do
          new(String.to_float(rate), ntsc)
        rescue
          ArgumentError -> nil
        end
      else
        result
      end

    result =
      if result == nil do
        try do
          parse_rational_string(rate, ntsc)
        rescue
          ArgumentError -> {:error, %ParseError{reason: :unrecognized_format}}
        end
      else
        result
      end

    result
  end

  @doc """
  As `Vtc.Framerate.new/2` but raises an error instead.
  """
  @spec new!(Ratio.t() | integer | float | String.t(), Vtc.Ntsc.t()) :: Vtc.Framerate.t()
  def new!(rate, ntsc) do
    case new(rate, ntsc) do
      {:ok, framerate} -> framerate
      {:error, err} -> raise err
    end
  end

  # validates that a rate is a proper drop-frame framerate.
  @spec validate_drop(Ratio.t(), Vtc.Ntsc.t()) :: :ok | {:error, Vtc.Framerate.ParseError.t()}
  defp validate_drop(rate, ntsc) do
    # if this value does not go cleanly into 29.97, then it cannot be a drop-frame
    # value.
    cond do
      ntsc != :Drop ->
        :ok

      not is_integer(rate / Ratio.new(30000, 1001)) ->
        {:error, %ParseError{reason: :bad_drop_rate}}

      true ->
        :ok
    end
  end

  # validates that the ntsc atom is one of our allowed values.
  @spec validate_ntsc(Vtc.Ntsc.t()) :: :ok | {:error, Vtc.Framerate.ParseError.t()}
  defp validate_ntsc(ntsc) do
    if ntsc not in [:Drop, :NonDrop, :None] do
      {:error, %ParseError{reason: :invalid_ntsc}}
    else
      :ok
    end
  end

  # coerces a rate to the closest proper NTSC playback rate.
  @spec coerce_ntsc_rate(Ratio.t(), Vtc.Ntsc.t()) :: Ratio.t()
  defp coerce_ntsc_rate(rate, ntsc) do
    if ntsc != :None and Ratio.denominator(rate) != 1001 do
      rate = Private.Rat.round_ratio?(rate)
      rate * 1000 / 1001
    else
      rate
    end
  end

  # The core parser used to parse a rational or integer rate value.
  @spec new_core(Ratio.t() | integer, Vtc.Ntsc.t()) :: parse_result
  defp new_core(rate, ntsc) do
    # validate that our ntsc atom is one of the acceptable values.
    with :ok <- validate_ntsc(ntsc),
         rate <- coerce_ntsc_rate(rate, ntsc),
         :ok <- validate_drop(rate, ntsc) do
      {:ok, %Vtc.Framerate{playback: rate, ntsc: ntsc}}
    else
      {:error, err} -> {:error, err}
    end
  end

  # parses a rational string value like '24/1'.
  @spec parse_rational_string(String.t(), Vtc.Ntsc.t()) :: parse_result
  defp parse_rational_string(str, ntsc) do
    split = String.split(str, "/")

    if Enum.count(split) != 2 do
      raise %ArgumentError{message: "not a fraction"}
    else
      [num_str, denom_str] = split

      numerator = String.to_integer(num_str)
      denominator = String.to_integer(denom_str)

      [numerator, denominator] =
        if denominator > numerator do
          [denominator, numerator]
        else
          [numerator, denominator]
        end

      new(Ratio.new(numerator, denominator), ntsc)
    end
  end

  @spec to_string(Vtc.Framerate.t()) :: String.t()
  def to_string(rate) do
    float_str =
      Ratio.to_float(rate.playback)
      |> Float.round(2)
      |> Float.to_string()

    ntsc_string =
      if Vtc.Ntsc.is_ntsc?(rate.ntsc) do
        " NTSC"
      else
        " fps"
      end

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
  def inspect(rate, _opts) do
    Vtc.Framerate.to_string(rate)
  end
end

defimpl String.Chars, for: Vtc.Framerate do
  @spec to_string(Vtc.Framerate.t()) :: String.t()
  def to_string(term) do
    Vtc.Framerate.to_string(term)
  end
end
