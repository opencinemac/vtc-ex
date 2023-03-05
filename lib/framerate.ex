defmodule Vtc.Ntsc do
  @moduledoc """
  Enum-like atom value for the various NTSC standards.

  These values are used when constructing and inspecting `Framerate` values.
  """

  @typedoc """
  Restricts the possible values of `Ntsc`.

  # Values

  - `:None`: Not an NTSC value
  - `:NonDrop` A non-drop NTSC value.
  - `:Drop` A drop-frame ntsc value.

  For more information on NTSC standards and framerate conventions, see
  [Frame.io's](frame.io)
  [blogpost](https://blog.frame.io/2017/07/17/timecode-and-frame-rates) on the subject.
  """
  @type t() :: :None | :NonDrop | :Drop

  @doc """
  Returns true if the value represents and NTSC framerate.

  So will return true on `:NonDrop` and `:Drop`.
  """
  @spec is_ntsc?(t()) :: boolean()
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

  alias Vtc.Private.Rational
  alias Vtc.Ntsc

  @enforce_keys [:playback, :ntsc]
  defstruct [:playback, :ntsc]

  @typedoc """
  Type of `Framerate`

  # Fields

  - `:playback`: The rational representation of the real-world playback speed as a
    fraction in frames-per-second.

  - `:ntsc`: Atom representing which, if any, NTSC convention this framerate adheres to.
  """
  @type t :: %__MODULE__{playback: Ratio.t(), ntsc: Ntsc.t()}

  @doc """
  The rational representation of the timecode timebase speed as a fraction in
  frames-per-second.
  """
  @spec timebase(t()) :: Ratio.t()
  def timebase(%__MODULE__{ntsc: :None} = framerate), do: framerate.playback
  def timebase(framerate), do: Rational.round_ratio?(framerate.playback)

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
  """
  @spec new(Ratio.t() | integer() | float() | String.t(), Ntsc.t()) :: parse_result()
  def new(%Ratio{} = rate, ntsc), do: new_core(rate, ntsc)
  def new(rate, ntsc) when is_integer(rate), do: new_core(rate, ntsc)
  def new(rate, :None) when is_float(rate), do: {:error, %ParseError{reason: :imprecise}}
  def new(rate, ntsc) when is_float(rate), do: new(Ratio.new(rate, 1.0), ntsc)

  def new(rate, ntsc) when is_binary(rate) do
    with :argument_error <- new_binary_do_try(fn -> new(String.to_integer(rate), ntsc) end),
         :argument_error <- new_binary_do_try(fn -> new(String.to_float(rate), ntsc) end),
         :argument_error <- new_binary_do_try(fn -> parse_rational_string(rate, ntsc) end) do
      {:error, %ParseError{reason: :unrecognized_format}}
    end
  end

  # tries to parse a binary value using `parser`. Catches `ArgumentError` exceptions
  # adn returns `:error` instead.
  @spec new_binary_do_try((() -> parse_result())) :: parse_result() | :argument_error
  defp new_binary_do_try(parser) do
    try do
      parser.()
    rescue
      ArgumentError -> :argument_error
    end
  end

  @doc """
  As `Framerate.new/2` but raises an error instead.
  """
  @spec new!(Ratio.t() | integer() | float() | String.t(), Ntsc.t()) :: t()
  def new!(rate, ntsc) do
    case new(rate, ntsc) do
      {:ok, framerate} -> framerate
      {:error, err} -> raise err
    end
  end

  # validates that a rate is a proper drop-frame framerate.
  @spec validate_drop(Ratio.t(), Ntsc.t()) :: :ok | {:error, ParseError.t()}
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

  # validates that the ntsc atom is one of our allowed values.
  @spec validate_ntsc(Ntsc.t()) :: :ok | {:error, ParseError.t()}
  defp validate_ntsc(ntsc) when ntsc in [:Drop, :NonDrop, :None], do: :ok
  defp validate_ntsc(_), do: {:error, %ParseError{reason: :invalid_ntsc}}

  # coerces a rate to the closest proper NTSC playback rate.
  @spec coerce_ntsc_rate(Ratio.t(), Ntsc.t()) :: Ratio.t()
  defp coerce_ntsc_rate(rate, ntsc) do
    if ntsc != :None and Ratio.denominator(rate) != 1001 do
      Rational.round_ratio?(rate) * 1000 / 1001
    else
      rate
    end
  end

  # The core parser used to parse a rational or integer rate value.
  @spec new_core(Ratio.t() | integer, Ntsc.t()) :: parse_result
  defp new_core(rate, ntsc) do
    # validate that our ntsc atom is one of the acceptable values.
    with :ok <- validate_ntsc(ntsc),
         rate <- coerce_ntsc_rate(rate, ntsc),
         :ok <- validate_drop(rate, ntsc) do
      {:ok, %__MODULE__{playback: rate, ntsc: ntsc}}
    end
  end

  # parses a rational string value like '24/1'.
  @spec parse_rational_string(String.t(), Ntsc.t()) :: parse_result
  defp parse_rational_string(str, ntsc) do
    split = String.split(str, "/")

    case Enum.count(split) do
      2 ->
        [num_str, denom_str] = split

        num = String.to_integer(num_str)
        denom = String.to_integer(denom_str)
        {num, denom} = if denom > num, do: {denom, num}, else: {num, denom}

        num
        |> Ratio.new(denom)
        |> new(ntsc)

      _ ->
        raise %ArgumentError{message: "not a fraction"}
    end
  end

  @spec to_string(t()) :: String.t()
  def to_string(rate) do
    float_str =
      Ratio.to_float(rate.playback)
      |> Float.round(2)
      |> Float.to_string()

    ntsc_string = if Ntsc.is_ntsc?(rate.ntsc), do: " NTSC", else: " fps"

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
