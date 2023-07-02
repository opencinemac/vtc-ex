defprotocol Vtc.Source.Frames do
  @moduledoc """
  Protocol which types can implement to be passed as the main value of
  `Framestamp.with_frames/2`.

  ## Implementations

  Out of the box, this protocol is implemented for the following types:

  - `Integer`

  - `String` & `BitString`

    - timecode ("01:00:00:00")

    - integer ("86400")

    - Feet+Frames ("5400+00")

  - [SMPTETimecodeStr](`Vtc.Source.Frames.SMPTETimecodeStr`)

  - [FeetAndFrames](`Vtc.Source.Frames.FeetAndFrames`)
  """

  alias Vtc.Framerate
  alias Vtc.Framestamp

  @typedoc """
  Result type of `frames/2`.
  """
  @type result() :: {:ok, integer()} | {:error, Framestamp.ParseError.t()}

  @doc """
  Returns the value as a frame count.

  # Arguments

  - **value**: The source value.

  - **rate**: The framerate of the framestamp being parsed.

  # Returns

  A result tuple with an integer value representing the frame count on success.
  """

  @spec frames(t(), Framerate.t()) :: result()
  def frames(value, rate)
end
