defmodule Vtc.TimecodeTest.TcParseCase do
  alias Vtc.Sources.Seconds
  alias Vtc.Sources.Frames

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

  @type t :: %__MODULE__{
          name: String.t(),
          rate: Framerate.t(),
          seconds_inputs: list(Seconds.t()),
          frames_inputs: list(Frames.t()),
          seconds: Ratio.t(),
          frames: integer(),
          timecode: String.t(),
          runtime: String.t(),
          premiere_ticks: integer(),
          feet_and_frames: String.t()
        }
end

defmodule Vtc.TimecodeTest.ParseHelpers do
  use Ratio

  alias Vtc.Timecode
  alias Vtc.TimecodeTest.TcParseCase

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

  @spec make_negative_input(input, Timecode.t()) :: input when [input: String.t() | integer()]
  def make_negative_input(input, tc) do
    cond do
      tc.frames == 0 -> input
      is_bitstring(input) -> "-" <> input
      true -> -input
    end
  end
end

defmodule Vtc.TimecodeTest.MalformedCase do
  @moduledoc false

  # Holds information for testing malformed timecode strings.

  defstruct [
    :val_in,
    :expected
  ]

  @type t :: %__MODULE__{val_in: String.t(), expected: String.t()}
end

defmodule Vtc.TimecodeTest do
  use ExUnit.Case
  use Ratio

  alias Vtc.Rates
  alias Vtc.Framerate
  alias Vtc.Timecode

  alias Vtc.TimecodeTest.ParseHelpers
  alias Vtc.TimecodeTest.TcParseCase
  alias Vtc.TimecodeTest.MalformedCase

  describe "#parse" do
    cases = [
      # 23.98 NTSC #########################
      ######################################
      %TcParseCase{
        name: "01:00:00:00 @ 23.98 NTSC",
        rate: Framerate.new!(23.98, :NonDrop),
        seconds_inputs: [
          Ratio.new(18_018, 5),
          3_603.6,
          "01:00:03.6"
        ],
        frames_inputs: [
          86_400,
          "01:00:00:00",
          "5400+00"
        ],
        seconds: Ratio.new(18_018, 5),
        frames: 86_400,
        timecode: "01:00:00:00",
        runtime: "01:00:03.6",
        premiere_ticks: 915_372_057_600_000,
        feet_and_frames: "5400+00"
      },
      %TcParseCase{
        name: "00:40:00:00 @ 23.98 NTSC",
        rate: Framerate.new!(23.98, :NonDrop),
        seconds_inputs: [
          Ratio.new(12_012, 5),
          2_402.4,
          "00:40:02.4"
        ],
        frames_inputs: [
          57_600,
          "00:40:00:00",
          "3600+00"
        ],
        seconds: Ratio.new(12_012, 5),
        frames: 57_600,
        timecode: "00:40:00:00",
        runtime: "00:40:02.4",
        premiere_ticks: 610_248_038_400_000,
        feet_and_frames: "3600+00"
      },
      # 29.97 Drop #########################
      ######################################
      %TcParseCase{
        name: "00:00:00;00 29.97 Drop-Frame",
        rate: Framerate.new!(29.97, :Drop),
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
        rate: Framerate.new!(29.97, :Drop),
        seconds_inputs: [
          Ratio.new(31_031, 15_000),
          2.068733333333333333333333333,
          "00:00:02.068733333"
        ],
        frames_inputs: [
          62,
          "00:00:02;02",
          "3+14"
        ],
        seconds: Ratio.new(31_031, 15_000),
        frames: 62,
        timecode: "00:00:02;02",
        runtime: "00:00:02.068733333",
        premiere_ticks: 525_491_366_400,
        feet_and_frames: "3+14"
      },
      %TcParseCase{
        name: "00:01:00;02 29.97 Drop-Frame",
        rate: Framerate.new!(29.97, :Drop),
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
        rate: Framerate.new!(29.97, :Drop),
        seconds_inputs: [
          Ratio.new(1_800_799, 15_000),
          120.0532666666666666666666667,
          "00:02:00.053266667"
        ],
        frames_inputs: [
          3598,
          "00:02:00;02",
          "224+14"
        ],
        seconds: Ratio.new(1_800_799, 15_000),
        frames: 3598,
        timecode: "00:02:00;02",
        runtime: "00:02:00.053266667",
        premiere_ticks: 30_495_450_585_600,
        feet_and_frames: "224+14"
      },
      %TcParseCase{
        name: "00:10:00;00 29.97 Drop-Frame",
        rate: Framerate.new!(29.97, :Drop),
        seconds_inputs: [
          Ratio.new(2_999_997, 5000),
          599.9994,
          "00:09:59.9994"
        ],
        frames_inputs: [
          17_982,
          "00:10:00;00",
          "1123+14"
        ],
        seconds: Ratio.new(2_999_997, 5000),
        frames: 17_982,
        timecode: "00:10:00;00",
        runtime: "00:09:59.9994",
        premiere_ticks: 152_409_447_590_400,
        feet_and_frames: "1123+14"
      },
      %TcParseCase{
        name: "00:11:00;02 29.97 Drop-Frame",
        rate: Framerate.new!(29.97, :Drop),
        seconds_inputs: [
          Ratio.new(3_300_297, 5000),
          660.0594,
          "00:11:00.0594"
        ],
        frames_inputs: [
          19_782,
          "00:11:00;02",
          "1236+06"
        ],
        seconds: Ratio.new(3_300_297, 5000),
        frames: 19_782,
        timecode: "00:11:00;02",
        runtime: "00:11:00.0594",
        premiere_ticks: 167_665_648_550_400,
        feet_and_frames: "1236+06"
      },
      %TcParseCase{
        name: "01:00:00;00 29.97 Drop-Frame",
        rate: Framerate.new!(29.97, :Drop),
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
        rate: Framerate.new!(59.94, :Drop),
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
        rate: Framerate.new!(59.94, :Drop),
        seconds_inputs: [
          Ratio.new(61_061, 60_000),
          1.017683333333333333333333333,
          "00:00:01.017683333"
        ],
        frames_inputs: [
          61,
          "00:00:01;01",
          "3+13"
        ],
        seconds: Ratio.new(61_061, 60_000),
        frames: 61,
        timecode: "00:00:01;01",
        runtime: "00:00:01.017683333",
        premiere_ticks: 258_507_849_600,
        feet_and_frames: "3+13"
      },
      %TcParseCase{
        name: "00:00:01;03 59.94 Drop-Frame",
        rate: Framerate.new!(59.94, :Drop),
        seconds_inputs: [
          Ratio.new(21_021, 20_000),
          1.05105,
          "00:00:01.05105"
        ],
        frames_inputs: [
          63,
          "00:00:01;03",
          "3+15"
        ],
        seconds: Ratio.new(21_021, 20_000),
        frames: 63,
        timecode: "00:00:01;03",
        runtime: "00:00:01.05105",
        premiere_ticks: 266_983_516_800,
        feet_and_frames: "3+15"
      },
      %TcParseCase{
        name: "00:01:00;04 59.94 Drop-Frame",
        rate: Framerate.new!(59.94, :Drop),
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

    for tc <- cases do
      case_name = tc.name
      @test_case tc
      @test_case_negative ParseHelpers.make_negative_case(tc)

      for {input_case, i} <- Enum.with_index(tc.seconds_inputs) do
        @input input_case
        test "#{case_name} - #{i}: #{input_case} - with_seconds" do
          parsed = Timecode.with_seconds(@input, @test_case.rate)
          check_parsed(@test_case, parsed)
        end

        @negative_input ParseHelpers.make_negative_input(input_case, tc)

        test "#{case_name} - #{i}: #{input_case} - with_seconds - negative" do
          parsed = Timecode.with_seconds(@negative_input, @test_case_negative.rate)
          check_parsed(@test_case_negative, parsed)
        end
      end

      for {input_case, i} <- Enum.with_index(tc.frames_inputs) do
        @input input_case
        test "#{case_name} - #{i}: #{input_case} - with_frames" do
          parsed = Timecode.with_frames(@input, @test_case.rate)
          check_parsed(@test_case, parsed)
        end

        @negative_input ParseHelpers.make_negative_input(input_case, tc)
        test "#{case_name} - #{i}: #{input_case} - with_frames - negative" do
          parsed = Timecode.with_frames(@negative_input, @test_case_negative.rate)
          check_parsed(@test_case_negative, parsed)
        end
      end

      ticks = tc.premiere_ticks

      test "#{case_name}: #{ticks} - with_premiere_ticks" do
        parsed = Timecode.with_premiere_ticks(@test_case.premiere_ticks, @test_case.rate)
        check_parsed(@test_case, parsed)
      end

      test "#{case_name}: #{ticks} - with_premiere_ticks!" do
        parsed = Timecode.with_premiere_ticks!(@test_case.premiere_ticks, @test_case.rate)
        check_parsed(@test_case, parsed)
      end
    end

    @spec check_parsed(TcParseCase.t(), Timecode.parse_result()) :: nil
    defp check_parsed(test_case, {_, _} = result) do
      assert {:ok, parsed} = result
      check_parsed(test_case, parsed)
    end

    @spec check_parsed(TcParseCase.t(), Timecode.t()) :: nil
    defp check_parsed(test_case, %Timecode{} = parsed) do
      assert test_case.seconds == parsed.seconds
      assert test_case.frames == Timecode.frames(parsed)
      assert test_case.timecode == Timecode.timecode(parsed)
      assert test_case.runtime == Timecode.runtime(parsed, 9)
      assert test_case.premiere_ticks == Timecode.premiere_ticks(parsed)
      assert test_case.feet_and_frames == Timecode.feet_and_frames(parsed)
      assert test_case.rate == parsed.rate
    end
  end

  describe "#parse malformed" do
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
      @test_case tc

      test "#{val_in} == #{expected}" do
        parsed = Timecode.with_frames!(@test_case.val_in, Rates.f23_98())
        assert @test_case.expected == Timecode.timecode(parsed)
      end
    end
  end

  describe "#parse partial tc" do
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
      @test_case tc

      test "#{val_in} == #{expected}" do
        parsed = Timecode.with_frames!(@test_case.val_in, Rates.f23_98())
        assert @test_case.expected == Timecode.timecode(parsed)
      end
    end
  end

  describe "#parse partial runtime" do
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
      @test_case tc

      test "#{val_in} == #{expected}" do
        parsed = Timecode.with_seconds!(@test_case.val_in, Rates.f24())
        assert @test_case.expected == Timecode.runtime(parsed, 9)
      end
    end
  end

  describe "#parse errors" do
    test "ParseTimecodeError - Format" do
      result = Timecode.with_frames("notatimecode", Rates.f24())
      assert {:error, %Timecode.ParseError{} = err} = result
      assert :unrecognized_format == err.reason
      assert "string format not recognized" = Timecode.ParseError.message(err)
    end

    test "ParseTimecodeError - Bad Drop Frame" do
      result = Timecode.with_frames("00:01:00;01", Rates.f29_97_df())
      assert {:error, %Timecode.ParseError{} = err} = result
      assert :bad_drop_frames == err.reason

      assert "frames value not allowed for drop-frame timecode. frame should have been dropped" =
               Timecode.ParseError.message(err)
    end

    test "ParseTimecodeError - Runtime Format" do
      result = Timecode.with_seconds("notatimecode", Rates.f24())
      assert {:error, %Timecode.ParseError{} = err} = result
      assert :unrecognized_format == err.reason
      assert "string format not recognized" = Timecode.ParseError.message(err)
    end

    test "ParseTimecodeError - with_frames! Throws" do
      assert_raise Timecode.ParseError, fn ->
        Timecode.with_frames!("notatimecode", Rates.f24())
      end
    end

    test "ParseTimecodeError - with_seconds! Throws" do
      assert_raise Timecode.ParseError, fn ->
        Timecode.with_seconds!("notatimecode", Rates.f24())
      end
    end
  end
end
