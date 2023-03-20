defprotocol Vtc.Source.PremiereTicks do
  @moduledoc """
  Protocol which types can implement to be passed as the main value of
  `Vtc.Timecode.with_premiere_ticks/3`.

  # Implementations

  Out of the box, this protocol is implemented for the following types:

  - `Integer`
  """

  @doc """
  Returns the number of Adobe Premiere Pro ticks as an integer.

  # Arguments

  - **value**: The source value.

  - **rate**: The framerate of the timecode being parsed.

  # Returns

  A result tuple with a rational representation of the seconds value using `Ratio` on
  success.
  """

  alias Vtc.Framerate
  alias Vtc.Timecode

  @typedoc """
  Result type of `ticks/3`.
  """
  @type result() :: {:ok, integer()} | {:error, Timecode.ParseError.t()}

  @spec ticks(t(), Framerate.t()) :: result()
  def ticks(value, rate)
end

defimpl Vtc.Source.PremiereTicks, for: Integer do
  alias Vtc.Framerate
  alias Vtc.Source.PremiereTicks

  @spec ticks(integer(), Framerate.t()) :: PremiereTicks.result()
  def ticks(value, _rate), do: {:ok, value}
end
