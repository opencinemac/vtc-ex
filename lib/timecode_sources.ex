defmodule Vtc.Sources do
  use Ratio

  @type seconds_result :: {:ok, Ratio.t() | integer} | {:error, Vtc.Timecode.ParseError.t()}

  defprotocol Seconds do
    @spec seconds(t, Vtc.Framerate.t()) :: Vtc.Sources.seconds_result()
    def seconds(value, rate)
  end

  defimpl Seconds, for: [Ratio, Integer] do
    @spec seconds(Ratio.t() | integer, Vtc.Framerate.t()) :: Vtc.Sources.seconds_result()
    def seconds(value, rate), do: Private.from_seconds_core(value, rate)
  end

  defimpl Seconds, for: Float do
    @spec seconds(float, Vtc.Framerate.t()) :: Vtc.Sources.seconds_result()
    def seconds(value, rate), do: Seconds.seconds(Ratio.new(value, 1), rate)
  end

  @type frames_result :: {:ok, integer} | {:error, Vtc.Timecode.ParseError.t()}

  defprotocol Frames do
    @spec frames(t, Vtc.Framerate.t()) :: Vtc.Sources.frames_result()
    def frames(value, rate)
  end

  defimpl Frames, for: Integer do
    @spec frames(integer, Vtc.Framerate.t()) :: Vtc.Sources.frames_result()
    def frames(value, _rate), do: {:ok, value}
  end

  defimpl Frames, for: [String, BitString] do
    @spec frames(String.t() | Bitstring, Vtc.Framerate.t()) :: Vtc.Sources.frames_result()
    def frames(value, rate), do: Private.parse_tc_string(value, rate)
  end
end
