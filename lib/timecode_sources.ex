defmodule Vtc.Sources do
  @moduledoc """
  Protocols for source values that can be used to construct a timecode.
  """

  use Ratio

  @typedoc """
  Result type of `Vtc.Sources.Seconds.seconds/2`.
  """
  @type seconds_result :: {:ok, Ratio.t() | integer} | {:error, Vtc.Timecode.ParseError.t()}

  defprotocol Seconds do
    @moduledoc """
    Protocol which types can implement to be passed as the main value of
    `Vtc.Timecode.with_seconds/2`.

    # Implementations

    Out of the box, this protocol is implemented for the following types:

    - `Ratio`
    - `Integer`
    - `Float`
    """

    @doc """
    Returns the value as a rational seconds value.

    # Arguments

    - **value**: The source value.

    - **rate**: The framerate of the timecode being parsed.

    # Returns

    A result tuple with a rational representation of the seconds value using `Ratio` on
    success.
    """
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

  @typedoc """
  Result type of `Vtc.Sources.Frames.frames/2`.
  """
  @type frames_result :: {:ok, integer} | {:error, Vtc.Timecode.ParseError.t()}

  defprotocol Frames do
    @moduledoc """
    Protocol which types can implement to be passed as the main value of
    `Vtc.Timecode.with_frames/2`.

    # Implementations

    Out of the box, this protocol is implemented for the following types:

    - `Integer`
    - `String`
    - `Bitstring`
    """

    @doc """
    Returns the value as a frame count.

    # Arguments

    - **value**: The source value.

    - **rate**: The framerate of the timecode being parsed.

    # Returns

    A result tuple with an integer value representing the frame count on success.
    """
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
