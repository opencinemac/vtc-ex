defimpl Vtc.Source.Seconds, for: [Ratio, Integer, Float] do
  alias Vtc.Framerate
  alias Vtc.Source.Seconds

  @spec seconds(Ratio.t(), Framerate.t()) :: Seconds.result()
  def seconds(value, _rate), do: {:ok, Ratio.new(value)}
end
