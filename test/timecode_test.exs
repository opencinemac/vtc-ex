defmodule TcParseCase do
  defstruct [
    :name,
    :rate,
    :seconds_inputs,
    :frames_inputs,
    :seconds,
    :frames,
    :timecode,
    :runtime,
    :premiere_ticks,
    :feet_and_frames
  ]

  @type t :: %TcParseCase{
          name: bitstring,
          rate: Vtc.Framerate.t(),
          seconds_inputs: list(Vtc.Sources.Seconds.t()),
          frames_inputs: list(Vtc.Sources.Frames.t()),
          seconds: Ratio.t(),
          frames: integer,
          timecode: String.t(),
          runtime: String.t(),
          premiere_ticks: integer,
          feet_and_frames: String.t()
        }
end

defmodule TimecodeParseTest do
  use ExUnit.Case
  use Ratio

  cases = [
    %TcParseCase{
      name: "01:00:00:00 @ 23.98 NTSC",
      rate: Vtc.Framerate.new!(23.98, :NonDrop),
      seconds_inputs: [
        Ratio.new(18018, 5),
        3603.6
      ],
      frames_inputs: [
        86400,
        "01:00:00:00"
      ],
      seconds: Ratio.new(18018, 5),
      frames: 86400,
      timecode: "01:00:00:00",
      runtime: "01:00:03.6",
      premiere_ticks: 915_372_057_600_000,
      feet_and_frames: "5400+00"
    }
  ]

  @spec check_parsed(TcParseCase.t(), Vtc.Timecode.parse_result()) :: nil
  def check_parsed(testCase, result) do
    assert {:ok, parsed} = result
    assert testCase.seconds == parsed.seconds
    assert testCase.frames == Vtc.Timecode.frames(parsed)
    assert testCase.timecode == Vtc.Timecode.timecode(parsed)
    assert testCase.rate == parsed.rate
  end

  for tc <- cases do
    caseName = tc.name
    @testCase tc

    for {inputCase, i} <- Enum.with_index(tc.seconds_inputs) do
      @input inputCase
      test "#{caseName} - #{i}: #{inputCase} - with_seconds" do
        parsed = Vtc.Timecode.with_seconds(@input, @testCase.rate)
        check_parsed(@testCase, parsed)
      end
    end

    for {inputCase, i} <- Enum.with_index(tc.frames_inputs) do
      @input inputCase
      test "#{caseName} - #{i}: #{inputCase} - with_frames" do
        parsed = Vtc.Timecode.with_frames(@input, @testCase.rate)
        check_parsed(@testCase, parsed)
      end
    end
  end
end
