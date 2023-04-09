defprotocol Vtc.Source.Seconds do
  @moduledoc """
  Protocol which types can implement to be passed as the main value of
  `Timecode.with_seconds/3`.

  ## Implementations

  Out of the box, this protocol is implemented for the following types:

  - `Ratio`
  - `Integer`
  - `Float`
  - `String`
    - runtime ("01:00:00.0")
    - decimal ("3600.0")
  """

  alias Vtc.Framerate
  alias Vtc.Timecode
  alias Vtc.Utils.Rational

  @typedoc """
  Result type of `seconds/2`.
  """
  @type result() :: {:ok, Rational.t()} | {:error, Timecode.ParseError.t()}

  @doc """
  Returns the value as a rational, real-world seconds value.

  ## Arguments

  - **value**: The source value.

  - **rate**: The framerate of the timecode being parsed.

  ## Returns

  A result tuple with a rational representation of the seconds value using `Ratio` on
  success.
  """
  @spec seconds(t(), Framerate.t()) :: result()
  def seconds(value, rate)
end

defimpl Vtc.Source.Seconds, for: [Ratio, Integer] do
  alias Vtc.Framerate
  alias Vtc.Source.Seconds
  alias Vtc.Utils.Parse
  alias Vtc.Utils.Rational

  @spec seconds(Rational.t(), Framerate.t()) :: Seconds.result()
  def seconds(value, _rate), do: {:ok, value}
end

defimpl Vtc.Source.Seconds, for: Float do
  alias Vtc.Framerate
  alias Vtc.Source.Seconds

  @spec seconds(float(), Framerate.t()) :: Seconds.result()
  def seconds(value, rate), do: value |> Ratio.new(1) |> Seconds.seconds(rate)
end

defimpl Vtc.Source.Seconds, for: [String, BitString] do
  alias Vtc.Framerate
  alias Vtc.Source.Seconds
  alias Vtc.Utils.Parse

  @spec seconds(String.t(), Framerate.t()) :: Seconds.result()
  def seconds(value, rate),
    do: Parse.parse_runtime_string(value, rate)
end
