defmodule Vtc.Ntsc do
  @type t :: :None | :NonDrop | :Drop

  @spec is_ntsc?(Vtc.Ntsc.t()) :: boolean
  def is_ntsc?(:None) do
    false
  end

  def is_ntsc?(ntsc) when is_atom(ntsc) do
    true
  end
end

defmodule Vtc.Framerate do
  use Ratio, comparison: true

  @enforce_keys [:playback, :ntsc]
  defstruct [:playback, :ntsc]

  @typedoc """
      Type that represents Examples struct with :playback as rational
      number which represents the playback speed of a timecode, and :ntsc, which
      is an atom representing which, if any, NTSC convention this framerate
      adheres to.
  """
  @type t :: %Vtc.Framerate{playback: Ratio.t(), ntsc: Vtc.Ntsc.t()}

  @spec timebase(Vtc.Framerate.t()) :: Ratio.t()
  def timebase(framerate) do
    if framerate.ntsc == :None do
      framerate.playback
    else
      Private.round_ratio?(framerate.playback)
    end
  end

  defmodule ParseError do
    defexception [:reason]

    @type t :: %ParseError{reason: :bad_drop_rate | :invalid_ntsc | :unrecognized_format}

    @spec message(Vtc.Framerate.ParseError.t()) :: String.t()
    def message(error) do
      case error.reason do
        :bad_drop_rate -> "drop-frame rates must be divisible by 30000/1001"
        :invalid_ntsc -> "ntsc is not a valid atom. must be :NonDrop, :Drop, or None"
        :unrecognized_format -> "framerate string format not recognized"
      end
    end
  end

  @spec new!(Ratio.t() | integer | float | String.t(), Vtc.Ntsc.t()) :: Vtc.Framerate.t()
  def new!(rate, ntsc) do
    case new?(rate, ntsc) do
      {:ok, framerate} -> framerate
      {:error, err} -> raise err
    end
  end

  @type parse_result :: {:ok, Vtc.Framerate.t()} | {:error, Vtc.Framerate.ParseError.t()}

  @spec new?(Ratio.t(), Vtc.Ntsc.t()) :: parse_result
  def new?(
        %Ratio{numerator: numerator, denominator: denominator} = rate,
        ntsc
      )
      when is_integer(numerator) and is_integer(denominator) do
    new_core(rate, ntsc)
  end

  @spec new?(integer, Vtc.Ntsc.t()) :: parse_result
  def new?(rate, ntsc) when is_integer(rate) do
    new_core(rate, ntsc)
  end

  @spec new?(float, Vtc.Ntsc.t()) :: parse_result
  def new?(rate, ntsc) when is_float(rate) do
    new?(Ratio.new(rate, 1.0), ntsc)
  end

  @spec new?(String.t(), Vtc.Ntsc.t()) :: parse_result
  def new?(rate, ntsc) when is_bitstring(rate) do
    result =
      try do
        new?(String.to_integer(rate), ntsc)
      rescue
        ArgumentError -> nil
      end

    result =
      if result == nil do
        try do
          new?(String.to_float(rate), ntsc)
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

  @spec validate_ntsc(Vtc.Ntsc.t()) :: :ok | {:error, Vtc.Framerate.ParseError.t()}
  defp validate_ntsc(ntsc) do
    if ntsc not in [:Drop, :NonDrop, :None] do
      {:error, %ParseError{reason: :invalid_ntsc}}
    else
      :ok
    end
  end

  @spec coerce_ntsc_rate(Ratio.t(), Vtc.Ntsc.t()) :: Ratio.t()
  defp coerce_ntsc_rate(rate, ntsc) do
    if ntsc != :None and Ratio.denominator(rate) != 1001 do
      rate = Private.round_ratio?(rate)
      rate * 1000 / 1001
    else
      rate
    end
  end

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

      new?(Ratio.new(numerator, denominator), ntsc)
    end
  end
end
