defimpl Vtc.Source.Frames, for: [String, BitString] do
  alias Vtc.Framerate
  alias Vtc.Source.Frames
  alias Vtc.Source.Frames.TimecodeStr
  alias Vtc.Source.Frames.FeetAndFrames

  @spec frames(String.t(), Framerate.t()) :: Frames.result()
  def frames(value, rate) do
    tc_result = Frames.frames(%TimecodeStr{in: value}, rate)

    with {:error, %{reason: reason}} when reason != :bad_drop_frames <- tc_result,
         {:ok, feet_and_frames} <- FeetAndFrames.from_string(value) do
      Frames.frames(feet_and_frames, rate)
    end
  end
end
