defprotocol Vtc.Source.Frames do
  @moduledoc """
  Protocol which types can implement to be passed as the main value of
  `Timecode.with_frames/2`.

  ## Implementations

  Out of the box, this protocol is implemented for the following types:

  - `Integer`
  - `String` & 'BitString'
    - timecode ("01:00:00:00")
    - integer ("86400")
    - Feet+Frames ("5400+00")
  """

  alias Vtc.Framerate
  alias Vtc.Timecode

  @typedoc """
  Result type of `frames/2`.
  """
  @type result() :: {:ok, integer()} | {:error, Timecode.ParseError.t()}

  @doc """
  Returns the value as a frame count.

  # Arguments

  - **value**: The source value.

  - **rate**: The framerate of the timecode being parsed.

  # Returns

  A result tuple with an integer value representing the frame count on success.
  """

  @spec frames(t(), Framerate.t()) :: result()
  def frames(value, rate)
end

defimpl Vtc.Source.Frames, for: Integer do
  alias Vtc.Framerate
  alias Vtc.Source.Frames

  @spec frames(integer(), Framerate.t()) :: Frames.result()
  def frames(value, _rate), do: {:ok, value}
end

defimpl Vtc.Source.Frames, for: [String, BitString] do
  alias Vtc.Framerate
  alias Vtc.Source.Frames
  alias Vtc.Utils.Parse

  @spec frames(String.t(), Framerate.t()) :: Frames.result()
  def frames(value, rate), do: Parse.parse_frames_string(value, rate)
end
