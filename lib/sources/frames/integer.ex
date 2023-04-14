defimpl Vtc.Source.Frames, for: Integer do
  alias Vtc.Framerate
  alias Vtc.Source.Frames

  @spec frames(integer(), Framerate.t()) :: Frames.result()
  def frames(value, _rate), do: {:ok, value}
end
