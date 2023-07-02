defprotocol Vtc.Source.Seconds do
  @moduledoc """
  Protocol which types can implement to be passed as the main value of
  `Framestamp.with_seconds/3`.

  ## Implementations

  Out of the box, this protocol is implemented for the following types:

  - `Integer`
  - `Float`
  - `Ratio`
  - `String`
    - runtime ("01:00:00.0")
    - decimal ("3600.0")
  - `Vtc.Source.Seconds.RuntimeStr`
  - `Vtc.Source.Seconds.PremiereTicks`
  """

  alias Vtc.Framerate
  alias Vtc.Framestamp

  @typedoc """
  Result type of `seconds/2`.
  """
  @type result() :: {:ok, Ratio.t()} | {:error, Framestamp.ParseError.t()}

  @doc """
  Returns the value as a rational, real-world seconds value.

  ## Arguments

  - **value**: The source value.

  - **rate**: The framerate of the framestamp being parsed.

  ## Returns

  A result tuple with a rational representation of the seconds value using `Ratio` on
  success.
  """
  @spec seconds(t(), Framerate.t()) :: result()
  def seconds(value, rate)
end
