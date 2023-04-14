defimpl Vtc.Source.Seconds, for: [String, BitString] do
  alias Vtc.Framerate
  alias Vtc.Source.Seconds
  alias Vtc.Source.Seconds.RuntimeStr

  @spec seconds(String.t(), Framerate.t()) :: Seconds.result()
  def seconds(value, rate), do: Seconds.seconds(%RuntimeStr{in: value}, rate)
end
