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

defmodule ParseHelpers do
  use Ratio

  @spec make_negative_case(TcParseCase.t()) :: TcParseCase.t()
  def make_negative_case(%TcParseCase{} = tc) do
    if tc.frames != 0 do
      %{
        tc
        | seconds: -tc.seconds,
          frames: -tc.frames,
          timecode: "-" <> tc.timecode,
          runtime: "-" <> tc.runtime,
          premiere_ticks: -tc.premiere_ticks,
          feet_and_frames: "-" <> tc.feet_and_frames
      }
    else
      tc
    end
  end

  def make_negative_input(input, tc) do
    cond do
      tc.frames == 0 -> input
      is_bitstring(input) -> "-" <> input
      true -> -input
    end
  end
end

defmodule TimecodeParseTest do
  use ExUnit.Case
  use Ratio

  cases = [
    # 23.98 NTSC #########################
    ######################################
    %TcParseCase{
      name: "01:00:00:00 @ 23.98 NTSC",
      rate: Vtc.Framerate.new!(23.98, :NonDrop),
      seconds_inputs: [
        Ratio.new(18018, 5),
        3603.6,
        "01:00:03.6"
      ],
      frames_inputs: [
        86400,
        "01:00:00:00",
        "5400+00"
      ],
      seconds: Ratio.new(18018, 5),
      frames: 86400,
      timecode: "01:00:00:00",
      runtime: "01:00:03.6",
      premiere_ticks: 915_372_057_600_000,
      feet_and_frames: "5400+00"
    },
    %TcParseCase{
      name: "00:40:00:00 @ 23.98 NTSC",
      rate: Vtc.Framerate.new!(23.98, :NonDrop),
      seconds_inputs: [
        Ratio.new(12012, 5),
        2402.4,
        "00:40:02.4"
      ],
      frames_inputs: [
        57600,
        "00:40:00:00",
        "3600+00"
      ],
      seconds: Ratio.new(12012, 5),
      frames: 57600,
      timecode: "00:40:00:00",
      runtime: "00:40:02.4",
      premiere_ticks: 610_248_038_400_000,
      feet_and_frames: "3600+00"
    },
    # 29.97 Drop #########################
    ######################################
    %TcParseCase{
      name: "00:00:00;00 29.97 Drop-Frame",
      rate: Vtc.Framerate.new!(29.97, :Drop),
      seconds_inputs: [
        Ratio.new(0, 1),
        0.0,
        0,
        "00:00:00.0"
      ],
      frames_inputs: [
        0,
        "00:00:00;00",
        "0+00"
      ],
      seconds: Ratio.new(0, 1),
      frames: 0,
      timecode: "00:00:00;00",
      runtime: "00:00:00.0",
      premiere_ticks: 0,
      feet_and_frames: "0+00"
    },
    %TcParseCase{
      name: "00:00:02;02 29.97 Drop-Frame",
      rate: Vtc.Framerate.new!(29.97, :Drop),
      seconds_inputs: [
        Ratio.new(31031, 15000),
        2.068733333333333333333333333,
        "00:00:02.068733333"
      ],
      frames_inputs: [
        62,
        "00:00:02;02",
        "3+14"
      ],
      seconds: Ratio.new(31031, 15000),
      frames: 62,
      timecode: "00:00:02;02",
      runtime: "00:00:02.068733333",
      premiere_ticks: 525_491_366_400,
      feet_and_frames: "3+14"
    },
    %TcParseCase{
      name: "00:01:00;02 29.97 Drop-Frame",
      rate: Vtc.Framerate.new!(29.97, :Drop),
      seconds_inputs: [
        Ratio.new(3003, 50),
        60.06,
        "00:01:00.06"
      ],
      frames_inputs: [
        1800,
        "00:01:00;02",
        "112+08"
      ],
      seconds: Ratio.new(3003, 50),
      frames: 1800,
      timecode: "00:01:00;02",
      runtime: "00:01:00.06",
      premiere_ticks: 15_256_200_960_000,
      feet_and_frames: "112+08"
    },
    %TcParseCase{
      name: "00:2:00;02 29.97 Drop-Frame",
      rate: Vtc.Framerate.new!(29.97, :Drop),
      seconds_inputs: [
        Ratio.new(1_800_799, 15000),
        120.0532666666666666666666667,
        "00:02:00.053266667"
      ],
      frames_inputs: [
        3598,
        "00:02:00;02",
        "224+14"
      ],
      seconds: Ratio.new(1_800_799, 15000),
      frames: 3598,
      timecode: "00:02:00;02",
      runtime: "00:02:00.053266667",
      premiere_ticks: 30_495_450_585_600,
      feet_and_frames: "224+14"
    },
    %TcParseCase{
      name: "00:10:00;00 29.97 Drop-Frame",
      rate: Vtc.Framerate.new!(29.97, :Drop),
      seconds_inputs: [
        Ratio.new(2_999_997, 5000),
        599.9994,
        "00:09:59.9994"
      ],
      frames_inputs: [
        17982,
        "00:10:00;00",
        "1123+14"
      ],
      seconds: Ratio.new(2_999_997, 5000),
      frames: 17982,
      timecode: "00:10:00;00",
      runtime: "00:09:59.9994",
      premiere_ticks: 152_409_447_590_400,
      feet_and_frames: "1123+14"
    },
    %TcParseCase{
      name: "00:11:00;02 29.97 Drop-Frame",
      rate: Vtc.Framerate.new!(29.97, :Drop),
      seconds_inputs: [
        Ratio.new(3_300_297, 5000),
        660.0594,
        "00:11:00.0594"
      ],
      frames_inputs: [
        19782,
        "00:11:00;02",
        "1236+06"
      ],
      seconds: Ratio.new(3_300_297, 5000),
      frames: 19782,
      timecode: "00:11:00;02",
      runtime: "00:11:00.0594",
      premiere_ticks: 167_665_648_550_400,
      feet_and_frames: "1236+06"
    },
    %TcParseCase{
      name: "01:00:00;00 29.97 Drop-Frame",
      rate: Vtc.Framerate.new!(29.97, :Drop),
      seconds_inputs: [
        Ratio.new(8_999_991, 2500),
        3599.9964,
        "00:59:59.9964"
      ],
      frames_inputs: [
        107_892,
        "01:00:00;00",
        "6743+04"
      ],
      seconds: Ratio.new(8_999_991, 2500),
      frames: 107_892,
      timecode: "01:00:00;00",
      runtime: "00:59:59.9964",
      premiere_ticks: 914_456_685_542_400,
      feet_and_frames: "6743+04"
    },
    # 59.94 NTSC DF ######################
    ######################################
    %TcParseCase{
      name: "00:00:00;00 59.94 Drop-Frame",
      rate: Vtc.Framerate.new!(59.94, :Drop),
      seconds_inputs: [
        Ratio.new(0, 1),
        0.0,
        "00:00:00.0"
      ],
      frames_inputs: [
        0,
        "00:00:00;00",
        "0+00"
      ],
      seconds: Ratio.new(0, 1),
      frames: 0,
      timecode: "00:00:00;00",
      runtime: "00:00:00.0",
      premiere_ticks: 0,
      feet_and_frames: "0+00"
    },
    %TcParseCase{
      name: "00:00:01;01 59.94 Drop-Frame",
      rate: Vtc.Framerate.new!(59.94, :Drop),
      seconds_inputs: [
        Ratio.new(61061, 60000),
        1.017683333333333333333333333,
        "00:00:01.017683333"
      ],
      frames_inputs: [
        61,
        "00:00:01;01",
        "3+13"
      ],
      seconds: Ratio.new(61061, 60000),
      frames: 61,
      timecode: "00:00:01;01",
      runtime: "00:00:01.017683333",
      premiere_ticks: 258_507_849_600,
      feet_and_frames: "3+13"
    },
    %TcParseCase{
      name: "00:00:01;03 59.94 Drop-Frame",
      rate: Vtc.Framerate.new!(59.94, :Drop),
      seconds_inputs: [
        Ratio.new(21021, 20000),
        1.05105,
        "00:00:01.05105"
      ],
      frames_inputs: [
        63,
        "00:00:01;03",
        "3+15"
      ],
      seconds: Ratio.new(21021, 20000),
      frames: 63,
      timecode: "00:00:01;03",
      runtime: "00:00:01.05105",
      premiere_ticks: 266_983_516_800,
      feet_and_frames: "3+15"
    },
    %TcParseCase{
      name: "00:01:00;04 59.94 Drop-Frame",
      rate: Vtc.Framerate.new!(59.94, :Drop),
      seconds_inputs: [
        Ratio.new(3003, 50),
        60.06,
        "00:01:00.06"
      ],
      frames_inputs: [
        3600,
        "00:01:00;04",
        "225+00"
      ],
      seconds: Ratio.new(3003, 50),
      frames: 3600,
      timecode: "00:01:00;04",
      runtime: "00:01:00.06",
      premiere_ticks: 15_256_200_960_000,
      feet_and_frames: "225+00"
    }
  ]

  @spec check_parsed(TcParseCase.t(), Vtc.Timecode.parse_result()) :: nil
  def check_parsed(testCase, {_, _} = result) do
    assert {:ok, parsed} = result
    check_parsed(testCase, parsed)
  end

  @spec check_parsed(TcParseCase.t(), Vtc.Timecode.t()) :: nil
  def check_parsed(testCase, %Vtc.Timecode{} = parsed) do
    assert testCase.seconds == parsed.seconds
    assert testCase.frames == Vtc.Timecode.frames(parsed)
    assert testCase.timecode == Vtc.Timecode.timecode(parsed)
    assert testCase.runtime == Vtc.Timecode.runtime(parsed, 9)
    assert testCase.premiere_ticks == Vtc.Timecode.premiere_ticks(parsed)
    assert testCase.feet_and_frames == Vtc.Timecode.feet_and_frames(parsed)
    assert testCase.rate == parsed.rate
  end

  for tc <- cases do
    caseName = tc.name
    @testCase tc
    @testCaseNegative ParseHelpers.make_negative_case(tc)

    for {inputCase, i} <- Enum.with_index(tc.seconds_inputs) do
      @input inputCase
      test "#{caseName} - #{i}: #{inputCase} - with_seconds" do
        parsed = Vtc.Timecode.with_seconds(@input, @testCase.rate)
        check_parsed(@testCase, parsed)
      end

      @negativeInput ParseHelpers.make_negative_input(inputCase, tc)

      test "#{caseName} - #{i}: #{inputCase} - with_seconds - negative" do
        parsed = Vtc.Timecode.with_seconds(@negativeInput, @testCaseNegative.rate)
        check_parsed(@testCaseNegative, parsed)
      end
    end

    for {inputCase, i} <- Enum.with_index(tc.frames_inputs) do
      @input inputCase
      test "#{caseName} - #{i}: #{inputCase} - with_frames" do
        parsed = Vtc.Timecode.with_frames(@input, @testCase.rate)
        check_parsed(@testCase, parsed)
      end

      @negativeInput ParseHelpers.make_negative_input(inputCase, tc)
      test "#{caseName} - #{i}: #{inputCase} - with_frames - negative" do
        parsed = Vtc.Timecode.with_frames(@negativeInput, @testCaseNegative.rate)
        check_parsed(@testCaseNegative, parsed)
      end
    end

    ticks = tc.premiere_ticks

    test "#{caseName}: #{ticks} - with_premiere_ticks" do
      parsed = Vtc.Timecode.with_premiere_ticks(@testCase.premiere_ticks, @testCase.rate)
      check_parsed(@testCase, parsed)
    end

    test "#{caseName}: #{ticks} - with_premiere_ticks!" do
      parsed = Vtc.Timecode.with_premiere_ticks!(@testCase.premiere_ticks, @testCase.rate)
      check_parsed(@testCase, parsed)
    end
  end
end

defmodule MalformedCase do
  defstruct [
    :val_in,
    :expected
  ]

  @type t :: %MalformedCase{val_in: String.t(), expected: String.t()}
end

defmodule TimecodeOverflowTest do
  use ExUnit.Case
  use Ratio

  cases = [
    %MalformedCase{
      val_in: "00:59:59:24",
      expected: "01:00:00:00"
    },
    %MalformedCase{
      val_in: "00:59:59:28",
      expected: "01:00:00:04"
    },
    %MalformedCase{
      val_in: "00:00:62:04",
      expected: "00:01:02:04"
    },
    %MalformedCase{
      val_in: "00:62:01:04",
      expected: "01:02:01:04"
    },
    %MalformedCase{
      val_in: "00:62:62:04",
      expected: "01:03:02:04"
    },
    %MalformedCase{
      val_in: "123:00:00:00",
      expected: "123:00:00:00"
    },
    %MalformedCase{
      val_in: "01:00:00:48",
      expected: "01:00:02:00"
    },
    %MalformedCase{
      val_in: "01:00:120:00",
      expected: "01:02:00:00"
    },
    %MalformedCase{
      val_in: "01:120:00:00",
      expected: "03:00:00:00"
    }
  ]

  for tc <- cases do
    val_in = tc.val_in
    expected = tc.expected
    @testCase tc

    test "#{val_in} == #{expected}" do
      parsed = Vtc.Timecode.with_frames!(@testCase.val_in, Vtc.Rate.f23_98())
      assert @testCase.expected == Vtc.Timecode.timecode(parsed)
    end
  end
end

defmodule TimecodePartialTest do
  use ExUnit.Case
  use Ratio

  cases = [
    %MalformedCase{
      val_in: "1:02:03:04",
      expected: "01:02:03:04"
    },
    %MalformedCase{
      val_in: "02:03:04",
      expected: "00:02:03:04"
    },
    %MalformedCase{
      val_in: "2:03:04",
      expected: "00:02:03:04"
    },
    %MalformedCase{
      val_in: "03:04",
      expected: "00:00:03:04"
    },
    %MalformedCase{
      val_in: "3:04",
      expected: "00:00:03:04"
    },
    %MalformedCase{
      val_in: "04",
      expected: "00:00:00:04"
    },
    %MalformedCase{
      val_in: "4",
      expected: "00:00:00:04"
    }
  ]

  for tc <- cases do
    val_in = tc.val_in
    expected = tc.expected
    @testCase tc

    test "#{val_in} == #{expected}" do
      parsed = Vtc.Timecode.with_frames!(@testCase.val_in, Vtc.Rate.f23_98())
      assert @testCase.expected == Vtc.Timecode.timecode(parsed)
    end
  end
end

defmodule RuntimePartialTest do
  use ExUnit.Case

  cases = [
    %MalformedCase{
      val_in: "1:02:03.5",
      expected: "01:02:03.5"
    },
    %MalformedCase{
      val_in: "02:03.5",
      expected: "00:02:03.5"
    },
    %MalformedCase{
      val_in: "2:03.5",
      expected: "00:02:03.5"
    },
    %MalformedCase{
      val_in: "03.5",
      expected: "00:00:03.5"
    },
    %MalformedCase{
      val_in: "3.5",
      expected: "00:00:03.5"
    },
    %MalformedCase{
      val_in: "0.5",
      expected: "00:00:00.5"
    }
  ]

  for tc <- cases do
    val_in = tc.val_in
    expected = tc.expected
    @testCase tc

    test "#{val_in} == #{expected}" do
      parsed = Vtc.Timecode.with_seconds!(@testCase.val_in, Vtc.Rate.f24())
      assert @testCase.expected == Vtc.Timecode.runtime(parsed, 9)
    end
  end
end

defmodule TestErrors do
  use ExUnit.Case

  test "ParseTimecodeError - Format" do
    result = Vtc.Timecode.with_frames("notatimecode", Vtc.Rate.f24())
    assert {:error, %Vtc.Timecode.ParseError{} = err} = result
    assert :unrecognized_format == err.reason
    assert "string format not recognized" = Vtc.Timecode.ParseError.message(err)
  end

  test "ParseTimecodeError - Bad Drop Frame" do
    result = Vtc.Timecode.with_frames("00:01:00;01", Vtc.Rate.f29_97_Df())
    assert {:error, %Vtc.Timecode.ParseError{} = err} = result
    assert :bad_drop_frames == err.reason

    assert "frames value not allowed for drop-frame timecode. frame should have been dropped" =
             Vtc.Timecode.ParseError.message(err)
  end

  test "ParseTimecodeError - Runtime Format" do
    result = Vtc.Timecode.with_seconds("notatimecode", Vtc.Rate.f24())
    assert {:error, %Vtc.Timecode.ParseError{} = err} = result
    assert :unrecognized_format == err.reason
    assert "string format not recognized" = Vtc.Timecode.ParseError.message(err)
  end

  test "ParseTimecodeError - with_frames! Throws" do
    assert_raise Vtc.Timecode.ParseError, fn ->
      Vtc.Timecode.with_frames!("notatimecode", Vtc.Rate.f24())
    end
  end

  test "ParseTimecodeError - with_seconds! Throws" do
    assert_raise Vtc.Timecode.ParseError, fn ->
      Vtc.Timecode.with_seconds!("notatimecode", Vtc.Rate.f24())
    end
  end
end
