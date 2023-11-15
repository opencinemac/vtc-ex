defmodule Vtc.FramestampTest.Parse do
  @moduledoc false
  use Vtc.Test.Support.TestCase

  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Rates
  alias Vtc.Source.Frames.FeetAndFrames
  alias Vtc.Source.Seconds.PremiereTicks
  alias Vtc.Utils.DropFrame

  parse_table = [
    # 23.98 NTSC #########################
    ######################################
    %{
      name: "01:00:00:00 @ 23.98 NTSC",
      rate: Rates.f23_98(),
      seconds_inputs: [
        Ratio.new(18_018, 5),
        3603.6,
        "01:00:03.6",
        %PremiereTicks{in: 915_372_057_600_000}
      ],
      frames_inputs: [
        86_400,
        "01:00:00:00",
        "5400+00",
        %FeetAndFrames{feet: 5400, frames: 0, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 2700, frames: 0, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 4320, frames: 0, film_format: :ff16mm}
      ],
      seconds: Ratio.new(18_018, 5),
      frames: 86_400,
      timecode: "01:00:00:00",
      runtime: "01:00:03.6",
      premiere_ticks: 915_372_057_600_000,
      feet_and_frames_35mm_4perf: "5400+00",
      feet_and_frames_35mm_2perf: "2700+00",
      feet_and_frames_16mm: "4320+00"
    },
    %{
      name: "00:40:00:00 @ 23.98 NTSC",
      rate: Rates.f23_98(),
      seconds_inputs: [
        Ratio.new(12_012, 5),
        2402.4,
        "00:40:02.4",
        %PremiereTicks{in: 610_248_038_400_000}
      ],
      frames_inputs: [
        57_600,
        "00:40:00:00",
        "3600+00",
        %FeetAndFrames{feet: 3600, frames: 0, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 1800, frames: 0, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 2880, frames: 0, film_format: :ff16mm}
      ],
      seconds: Ratio.new(12_012, 5),
      frames: 57_600,
      timecode: "00:40:00:00",
      runtime: "00:40:02.4",
      premiere_ticks: 610_248_038_400_000,
      feet_and_frames_35mm_4perf: "3600+00",
      feet_and_frames_35mm_2perf: "1800+00",
      feet_and_frames_16mm: "2880+00"
    },
    %{
      name: "23:13:29:07 @ 23.98 NTSC",
      rate: Rates.f23_98(),
      seconds_inputs: [
        Ratio.new(2_008_629_623, 24_000),
        83_692.900958333,
        "23:14:52.900958333",
        %PremiereTicks{in: 21_259_335_929_832_000}
      ],
      frames_inputs: [
        2_006_623,
        "23:13:29:07",
        "125413+15",
        %FeetAndFrames{feet: 125_413, frames: 15, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 62_706, frames: 31, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 100_331, frames: 03, film_format: :ff16mm}
      ],
      seconds: Ratio.new(2_008_629_623, 24_000),
      frames: 2_006_623,
      timecode: "23:13:29:07",
      runtime: "23:14:52.900958333",
      premiere_ticks: 21_259_335_929_832_000,
      feet_and_frames_35mm_4perf: "125413+15",
      feet_and_frames_35mm_2perf: "62706+31",
      feet_and_frames_16mm: "100331+03"
    },
    # 24 True ############################
    ######################################
    %{
      name: "01:00:00:00 @ 24",
      rate: Rates.f24(),
      seconds_inputs: [
        3600,
        "01:00:00.0",
        %PremiereTicks{in: 914_457_600_000_000}
      ],
      frames_inputs: [
        86_400,
        "01:00:00:00",
        "5400+00",
        %FeetAndFrames{feet: 5400, frames: 0, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 2700, frames: 0, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 4320, frames: 0, film_format: :ff16mm}
      ],
      seconds: Ratio.new(3600),
      frames: 86_400,
      timecode: "01:00:00:00",
      runtime: "01:00:00.0",
      premiere_ticks: 914_457_600_000_000,
      feet_and_frames_35mm_4perf: "5400+00",
      feet_and_frames_35mm_2perf: "2700+00",
      feet_and_frames_16mm: "4320+00"
    },
    # 29.97 Drop #########################
    ######################################
    %{
      name: "00:00:00;00 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
      seconds_inputs: [
        0,
        0.0,
        "00:00:00.0",
        %PremiereTicks{in: 0}
      ],
      frames_inputs: [
        0,
        "00:00:00;00",
        "0+00",
        %FeetAndFrames{feet: 0, frames: 0, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 0, frames: 0, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 0, frames: 0, film_format: :ff16mm}
      ],
      seconds: Ratio.new(0),
      frames: 0,
      timecode: "00:00:00;00",
      runtime: "00:00:00.0",
      premiere_ticks: 0,
      feet_and_frames_35mm_4perf: "0+00",
      feet_and_frames_35mm_2perf: "0+00",
      feet_and_frames_16mm: "0+00"
    },
    %{
      name: "00:01:01;00 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
      seconds_inputs: [
        Ratio.new(457_457, 7500),
        "00:01:00.994266667",
        %PremiereTicks{in: 15_493_519_641_600}
      ],
      frames_inputs: [
        1828,
        "00:01:01;00",
        "114+04",
        %FeetAndFrames{feet: 114, frames: 4, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 57, frames: 4, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 91, frames: 8, film_format: :ff16mm}
      ],
      seconds: Ratio.new(457_457, 7500),
      frames: 1828,
      timecode: "00:01:01;00",
      runtime: "00:01:00.994266667",
      premiere_ticks: 15_493_519_641_600,
      feet_and_frames_35mm_4perf: "114+04",
      feet_and_frames_35mm_2perf: "57+04",
      feet_and_frames_16mm: "91+08"
    },
    %{
      name: "00:00:02;02 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
      seconds_inputs: [
        Ratio.new(31_031, 15_000),
        2.068733333333333333333333333,
        "00:00:02.068733333",
        %PremiereTicks{in: 525_491_366_400}
      ],
      frames_inputs: [
        62,
        "00:00:02;02",
        "3+14",
        %FeetAndFrames{feet: 3, frames: 14, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 1, frames: 30, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 3, frames: 2, film_format: :ff16mm}
      ],
      seconds: Ratio.new(31_031, 15_000),
      frames: 62,
      timecode: "00:00:02;02",
      runtime: "00:00:02.068733333",
      premiere_ticks: 525_491_366_400,
      feet_and_frames_35mm_4perf: "3+14",
      feet_and_frames_35mm_2perf: "1+30",
      feet_and_frames_16mm: "3+02"
    },
    %{
      name: "00:01:00;02 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
      seconds_inputs: [
        Ratio.new(3003, 50),
        60.06,
        "00:01:00.06",
        %PremiereTicks{in: 15_256_200_960_000}
      ],
      frames_inputs: [
        1800,
        "00:01:00;02",
        "112+08",
        %FeetAndFrames{feet: 112, frames: 8, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 56, frames: 8, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 90, frames: 0, film_format: :ff16mm}
      ],
      seconds: Ratio.new(3003, 50),
      frames: 1800,
      timecode: "00:01:00;02",
      runtime: "00:01:00.06",
      premiere_ticks: 15_256_200_960_000,
      feet_and_frames_35mm_4perf: "112+08",
      feet_and_frames_35mm_2perf: "56+08",
      feet_and_frames_16mm: "90+00"
    },
    %{
      name: "00:2:00;02 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
      seconds_inputs: [
        Ratio.new(1_800_799, 15_000),
        120.0532666666666666666666667,
        "00:02:00.053266667",
        %PremiereTicks{in: 30_495_450_585_600}
      ],
      frames_inputs: [
        3598,
        "00:02:00;02",
        "224+14",
        %FeetAndFrames{feet: 224, frames: 14, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 112, frames: 14, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 179, frames: 18, film_format: :ff16mm}
      ],
      seconds: Ratio.new(1_800_799, 15_000),
      frames: 3598,
      timecode: "00:02:00;02",
      runtime: "00:02:00.053266667",
      premiere_ticks: 30_495_450_585_600,
      feet_and_frames_35mm_4perf: "224+14",
      feet_and_frames_35mm_2perf: "112+14",
      feet_and_frames_16mm: "179+18"
    },
    %{
      name: "00:10:00;00 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
      seconds_inputs: [
        Ratio.new(2_999_997, 5000),
        599.9994,
        "00:09:59.9994",
        %PremiereTicks{in: 152_409_447_590_400}
      ],
      frames_inputs: [
        17_982,
        "00:10:00;00",
        "1123+14",
        %FeetAndFrames{feet: 1123, frames: 14, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 561, frames: 30, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 899, frames: 2, film_format: :ff16mm}
      ],
      seconds: Ratio.new(2_999_997, 5000),
      frames: 17_982,
      timecode: "00:10:00;00",
      runtime: "00:09:59.9994",
      premiere_ticks: 152_409_447_590_400,
      feet_and_frames_35mm_4perf: "1123+14",
      feet_and_frames_35mm_2perf: "561+30",
      feet_and_frames_16mm: "899+02"
    },
    %{
      name: "00:11:00;02 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
      seconds_inputs: [
        Ratio.new(3_300_297, 5000),
        660.0594,
        "00:11:00.0594",
        %PremiereTicks{in: 167_665_648_550_400}
      ],
      frames_inputs: [
        19_782,
        "00:11:00;02",
        "1236+06",
        %FeetAndFrames{feet: 1236, frames: 6, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 618, frames: 6, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 989, frames: 2, film_format: :ff16mm}
      ],
      seconds: Ratio.new(3_300_297, 5000),
      frames: 19_782,
      timecode: "00:11:00;02",
      runtime: "00:11:00.0594",
      premiere_ticks: 167_665_648_550_400,
      feet_and_frames_35mm_4perf: "1236+06",
      feet_and_frames_35mm_2perf: "618+06",
      feet_and_frames_16mm: "989+02"
    },
    %{
      name: "01:00:00;00 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
      seconds_inputs: [
        Ratio.new(8_999_991, 2500),
        3599.9964,
        "00:59:59.9964",
        %PremiereTicks{in: 914_456_685_542_400}
      ],
      frames_inputs: [
        107_892,
        "01:00:00;00",
        "6743+04",
        %FeetAndFrames{feet: 6743, frames: 4, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 3371, frames: 20, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 5394, frames: 12, film_format: :ff16mm}
      ],
      seconds: Ratio.new(8_999_991, 2500),
      frames: 107_892,
      timecode: "01:00:00;00",
      runtime: "00:59:59.9964",
      premiere_ticks: 914_456_685_542_400,
      feet_and_frames_35mm_4perf: "6743+04",
      feet_and_frames_35mm_2perf: "3371+20",
      feet_and_frames_16mm: "5394+12"
    },
    # 59.94 NTSC DF ######################
    ######################################
    %{
      name: "00:00:00;00 59.94 Drop-Frame",
      rate: Rates.f59_94_df(),
      seconds_inputs: [
        Ratio.new(0),
        0.0,
        "00:00:00.0",
        %PremiereTicks{in: 0}
      ],
      frames_inputs: [
        0,
        "00:00:00;00",
        "0+00",
        %FeetAndFrames{feet: 0, frames: 0, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 0, frames: 0, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 0, frames: 0, film_format: :ff16mm}
      ],
      seconds: Ratio.new(0),
      frames: 0,
      timecode: "00:00:00;00",
      runtime: "00:00:00.0",
      premiere_ticks: 0,
      feet_and_frames_35mm_4perf: "0+00",
      feet_and_frames_35mm_2perf: "0+00",
      feet_and_frames_16mm: "0+00"
    },
    %{
      name: "00:00:01;01 59.94 Drop-Frame",
      rate: Rates.f59_94_df(),
      seconds_inputs: [
        Ratio.new(61_061, 60_000),
        1.017683333333333333333333333,
        "00:00:01.017683333",
        %PremiereTicks{in: 258_507_849_600}
      ],
      frames_inputs: [
        61,
        "00:00:01;01",
        "3+13",
        %FeetAndFrames{feet: 3, frames: 13, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 1, frames: 29, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 3, frames: 1, film_format: :ff16mm}
      ],
      seconds: Ratio.new(61_061, 60_000),
      frames: 61,
      timecode: "00:00:01;01",
      runtime: "00:00:01.017683333",
      premiere_ticks: 258_507_849_600,
      feet_and_frames_35mm_4perf: "3+13",
      feet_and_frames_35mm_2perf: "1+29",
      feet_and_frames_16mm: "3+01"
    },
    %{
      name: "00:00:01;03 59.94 Drop-Frame",
      rate: Rates.f59_94_df(),
      seconds_inputs: [
        Ratio.new(21_021, 20_000),
        1.05105,
        "00:00:01.05105",
        %PremiereTicks{in: 266_983_516_800}
      ],
      frames_inputs: [
        63,
        "00:00:01;03",
        "3+15",
        %FeetAndFrames{feet: 3, frames: 15, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 1, frames: 31, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 3, frames: 3, film_format: :ff16mm}
      ],
      seconds: Ratio.new(21_021, 20_000),
      frames: 63,
      timecode: "00:00:01;03",
      runtime: "00:00:01.05105",
      premiere_ticks: 266_983_516_800,
      feet_and_frames_35mm_4perf: "3+15",
      feet_and_frames_35mm_2perf: "1+31",
      feet_and_frames_16mm: "3+03"
    },
    %{
      name: "00:01:00;04 59.94 Drop-Frame",
      rate: Rates.f59_94_df(),
      seconds_inputs: [
        Ratio.new(3003, 50),
        60.06,
        "00:01:00.06",
        %PremiereTicks{in: 15_256_200_960_000}
      ],
      frames_inputs: [
        3600,
        "00:01:00;04",
        "225+00",
        %FeetAndFrames{feet: 225, frames: 0, film_format: :ff35mm_4perf},
        %FeetAndFrames{feet: 112, frames: 16, film_format: :ff35mm_2perf},
        %FeetAndFrames{feet: 180, frames: 0, film_format: :ff16mm}
      ],
      seconds: Ratio.new(3003, 50),
      frames: 3600,
      timecode: "00:01:00;04",
      runtime: "00:01:00.06",
      premiere_ticks: 15_256_200_960_000,
      feet_and_frames_35mm_4perf: "225+00",
      feet_and_frames_35mm_2perf: "112+16",
      feet_and_frames_16mm: "180+00"
    }
  ]

  # The fields test case fields we should negate when we are testing on negative values.
  @negate_fields [
    :seconds,
    :frames,
    :timecode,
    :runtime,
    :premiere_ticks,
    :feet_and_frames_35mm_4perf,
    :feet_and_frames_35mm_2perf,
    :feet_and_frames_16mm,
    :input_case
  ]

  seconds_table =
    parse_table
    |> Enum.with_index()
    |> Enum.flat_map(fn {test_case, test_index} ->
      for {input_case, input_index} <- Enum.with_index(test_case.seconds_inputs) do
        test_case
        |> Map.put(:index, test_index)
        |> Map.put(:input_case, input_case)
        |> Map.put(:input_index, input_index)
      end
    end)

  frames_table =
    parse_table
    |> Enum.with_index()
    |> Enum.flat_map(fn {test_case, test_index} ->
      for {input_case, input_index} <- Enum.with_index(test_case.frames_inputs) do
        test_case
        |> Map.put(:index, test_index)
        |> Map.put(:input_case, input_case)
        |> Map.put(:input_index, input_index)
      end
    end)

  with_seconds_round_table = [
    %{
      input: Ratio.new(239, 240),
      opts: [],
      description: "round :closest implied",
      expected: Ratio.new(1)
    },
    %{
      input: Ratio.new(-239, 240),
      opts: [],
      description: "round :closest implied negative",
      expected: Ratio.new(-1)
    },
    %{
      input: Ratio.new(239, 240),
      opts: [round: :closest],
      description: "",
      expected: Ratio.new(1)
    },
    %{
      input: Ratio.new(-239, 240),
      opts: [round: :closest],
      description: "negative",
      expected: Ratio.new(-1)
    },
    %{
      input: Ratio.new(234, 240),
      opts: [round: :closest],
      description: "towards zero",
      expected: Ratio.new(23, 24)
    },
    %{
      input: Ratio.new(-234, 240),
      opts: [round: :closest],
      description: "towards zero negative",
      expected: Ratio.new(-23, 24)
    },
    %{
      input: Ratio.new(239, 240),
      opts: [round: :floor],
      description: "",
      expected: Ratio.new(23, 24)
    },
    %{
      input: Ratio.new(-231, 240),
      opts: [round: :floor],
      description: "negative",
      expected: Ratio.new(-1)
    },
    %{
      input: Ratio.new(231, 240),
      opts: [round: :ceil],
      description: "",
      expected: Ratio.new(1)
    },
    %{
      input: Ratio.new(-239, 240),
      opts: [round: :ceil],
      description: "negative",
      expected: Ratio.new(-23, 24)
    }
  ]

  describe "#with_seconds/3" do
    setup context, do: TestCase.setup_negates(context)

    table_test "<%= name %> | <%= input_case %> | <%= rate %>", seconds_table, test_case do
      %{rate: rate, input_case: input_case} = test_case

      input_case
      |> Framestamp.with_seconds(rate)
      |> check_parsed(test_case)
    end

    @tag negate: @negate_fields
    table_test "<%= name %> | <%= input_case %> | <%= rate %> | negative", seconds_table, test_case do
      %{rate: rate, input_case: input_case} = test_case

      input_case
      |> Framestamp.with_seconds(rate)
      |> check_parsed(test_case)
    end

    # Sub 1fps framerates can cause issues with our validations, so we want to test
    # some examples of that here.
    round_sub_1_fps_table = [
      %{input: Ratio.new(3), expected: Ratio.new(3)},
      %{input: Ratio.new(-3), expected: Ratio.new(-3)},
      %{input: Ratio.new(2), expected: Ratio.new(3)},
      %{input: Ratio.new(-2), expected: Ratio.new(-3)},
      %{input: Ratio.new(1), expected: Ratio.new(0)},
      %{input: Ratio.new(-1), expected: Ratio.new(0)},
      %{input: Ratio.new(0), expected: Ratio.new(0)}
    ]

    table_test "round | :closest | <%= input %> @ 1/3 fps -> <%= expected %>", round_sub_1_fps_table, test_case do
      %{input: input, expected: expected} = test_case

      rate = Framerate.new!(Ratio.new(1, 3), ntsc: nil)

      assert {:ok, result} = Framestamp.with_seconds(input, rate)
      assert result.seconds == expected
    end

    table_test "opts: <%= opts %> <%= description %>", with_seconds_round_table, test_case do
      %{input: input, opts: opts, expected: expected} = test_case
      {:ok, %Framestamp{seconds: ^expected}} = Framestamp.with_seconds(input, Rates.f24(), opts)
    end

    test "ParseTimecodeError when partial frames | round | :off" do
      {:error, %Framestamp.ParseError{} = error} = Framestamp.with_seconds(Ratio.new(239, 240), Rates.f24(), round: :off)

      expected_message = "`seconds` is not cleanly divisible by `rate.playback`"

      assert :partial_frame == error.reason
      assert Framestamp.ParseError.message(error) == expected_message
    end

    test "ParseTimecodeError when bad format" do
      {:error, %Framestamp.ParseError{} = error} = Framestamp.with_seconds("notatimecode", Rates.f24())

      assert :unrecognized_format == error.reason
      assert "string format not recognized" = Framestamp.ParseError.message(error)
    end
  end

  describe "#with_seconds!/3" do
    setup context, do: TestCase.setup_negates(context)

    table_test "<%= name %> | <%= input_case %> | <%= rate %>", seconds_table, test_case do
      %{rate: rate, input_case: input_case} = test_case

      input_case
      |> Framestamp.with_seconds!(rate)
      |> check_parsed!(test_case)
    end

    @tag negate: @negate_fields
    @tag :some_tag
    table_test "<%= name %>! | <%= input_case %> | <%= rate %> | negative", seconds_table, test_case do
      %{rate: rate, input_case: input_case} = test_case

      input_case
      |> Framestamp.with_seconds!(rate)
      |> check_parsed!(test_case)
    end

    table_test "opts: <%= opts %> <%= description %>", with_seconds_round_table, test_case do
      %{input: input, opts: opts, expected: expected} = test_case
      %Framestamp{seconds: ^expected} = Framestamp.with_seconds!(input, Rates.f24(), opts)
    end

    test "ParseTimecodeError when partial frames | round | :off" do
      error =
        assert_raise Framestamp.ParseError, fn ->
          Framestamp.with_seconds!(Ratio.new(239, 240), Rates.f24(), round: :off)
        end

      expected_message = "`seconds` is not cleanly divisible by `rate.playback`"

      assert :partial_frame == error.reason
      assert Framestamp.ParseError.message(error) == expected_message
    end

    test "ParseTimecodeError throws" do
      assert_raise Framestamp.ParseError, fn ->
        Framestamp.with_seconds!("notatimecode", Rates.f24())
      end
    end
  end

  describe "#with_frames/2" do
    table_test "#{test_case.name} | #{inspect(test_case.input_case)} | #{test_case.rate}", frames_table, test_case do
      %{rate: rate, input_case: input_case} = test_case

      input_case
      |> Framestamp.with_frames(rate)
      |> check_parsed(test_case)
    end

    @tag negate: @negate_fields
    table_test "<%= name %>! | <%= input_case %> | <%= rate %> | negative", frames_table, test_case do
      %{rate: rate, input_case: input_case} = test_case

      input_case
      |> Framestamp.with_frames(rate)
      |> check_parsed(test_case)
    end

    round_trip_tc_table = [
      %{smpte_timecode: "23:58:34;10", rate: Rates.f29_97_df()},
      %{smpte_timecode: "23:58:33;46", rate: Rates.f59_94_df()},
      %{smpte_timecode: "23:58:36;11", rate: Framerate.new!(Ratio.new(90_000, 1001), ntsc: :drop)},
      %{smpte_timecode: "23:58:33;75", rate: Framerate.new!(Ratio.new(90_000, 1001), ntsc: :drop)}
    ]

    table_test "round trip <%= smpte_timecode %> @ <%= rate %>", round_trip_tc_table, test_case do
      %{smpte_timecode: smpte_timecode, rate: rate} = test_case

      assert {:ok, framestamp} = Framestamp.with_frames(smpte_timecode, rate)
      assert Framestamp.smpte_timecode(framestamp) == smpte_timecode
    end

    table_test "round trip <%= smpte_timecode %> @ <%= rate %> | frames", round_trip_tc_table, test_case do
      %{smpte_timecode: smpte_timecode, rate: rate} = test_case

      assert {:ok, framestamp} = Framestamp.with_frames(smpte_timecode, rate)

      frames = Framestamp.frames(framestamp)
      assert {:ok, ^framestamp} = Framestamp.with_frames(frames, rate)
    end

    test "29.97 DF max frames == 24:00:00;00" do
      assert {:ok, framestamp} =
               Rates.f29_97_df()
               |> DropFrame.max_frames()
               |> Framestamp.with_frames(Rates.f29_97_df())

      assert Framestamp.smpte_timecode(framestamp) == "24:00:00;00"
    end

    test "59.94 DF max frames == 24:00:00;00" do
      assert {:ok, framestamp} =
               Rates.f59_94_df()
               |> DropFrame.max_frames()
               |> Framestamp.with_frames(Rates.f59_94_df())

      assert Framestamp.smpte_timecode(framestamp) == "24:00:00;00"
    end

    test "ParseTimecodeError - Format" do
      assert {:error, %Framestamp.ParseError{} = error} = Framestamp.with_frames("notatimecode", Rates.f24())

      assert :unrecognized_format == error.reason
      assert "string format not recognized" = Framestamp.ParseError.message(error)
    end

    test "ParseTimecodeError - Bad Drop Frame" do
      assert {:error, %Framestamp.ParseError{} = error} = Framestamp.with_frames("00:01:00;01", Rates.f29_97_df())

      assert :bad_drop_frames == error.reason

      assert "frames value not allowed for drop-frame timecode. frame should have been dropped" =
               Framestamp.ParseError.message(error)
    end
  end

  describe "#with_frames!/2" do
    table_test "<%= name %>! | <%= input_case %> | <%= rate %>", frames_table, test_case do
      %{rate: rate, input_case: input_case} = test_case

      input_case
      |> Framestamp.with_frames!(rate)
      |> check_parsed!(test_case)
    end

    @tag negate: @negate_fields
    table_test "<%= name %>! | <%= input_case %> | <%= rate %> | negative", frames_table, test_case do
      %{rate: rate, input_case: input_case} = test_case

      input_case
      |> Framestamp.with_frames!(rate)
      |> check_parsed!(test_case)
    end

    test "ParseTimecodeError throws" do
      assert_raise Framestamp.ParseError, fn ->
        Framestamp.with_frames!("notatimecode", Rates.f24())
      end
    end
  end

  @ppro_ticks_per_frame div(PremiereTicks.per_second(), 24)

  describe "#with_seconds/3 | Premiere Ticks" do
    round_table = [
      %{
        input: div(@ppro_ticks_per_frame, 2),
        opts: [],
        description: "round :closest implied",
        expected: Ratio.new(1, 24)
      },
      %{
        input: div(-@ppro_ticks_per_frame, 2),
        opts: [],
        description: "round :closest implied negative",
        expected: Ratio.new(-1, 24)
      },
      %{
        input: div(@ppro_ticks_per_frame, 2),
        opts: [round: :closest],
        description: "",
        expected: Ratio.new(1, 24)
      },
      %{
        input: div(-@ppro_ticks_per_frame, 2),
        opts: [round: :closest],
        description: "negative",
        expected: Ratio.new(-1, 24)
      },
      %{
        input: div(@ppro_ticks_per_frame, 2) - 1,
        opts: [round: :closest],
        description: "towards zero",
        expected: Ratio.new(0)
      },
      %{
        input: -(div(@ppro_ticks_per_frame, 2) - 1),
        opts: [round: :closest],
        description: "towards zero negative",
        expected: Ratio.new(0)
      },
      %{
        input: div(@ppro_ticks_per_frame, 4),
        opts: [round: :ceil],
        description: "",
        expected: Ratio.new(1, 24)
      },
      %{
        input: div(-@ppro_ticks_per_frame, 4),
        opts: [round: :ceil],
        description: "negative",
        expected: Ratio.new(0)
      },
      %{
        input: @ppro_ticks_per_frame - 1,
        opts: [round: :floor],
        description: "",
        expected: Ratio.new(0)
      },
      %{
        input: -(@ppro_ticks_per_frame - 1),
        opts: [round: :floor],
        description: "negative",
        expected: Ratio.new(-1, 24)
      }
    ]

    table_test "opts: <%= opts %> <%= description %>", round_table, test_case do
      %{input: input, opts: opts, expected: expected} = test_case

      premiere_ticks = %PremiereTicks{in: input}
      %Framestamp{seconds: ^expected} = Framestamp.with_seconds!(premiere_ticks, Rates.f24(), opts)
    end

    test "ParseTimecodeError when partial frames | round | :off" do
      assert {:error, %Framestamp.ParseError{} = error} =
               (PremiereTicks.per_second() - 1)
               |> then(&%PremiereTicks{in: &1})
               |> Framestamp.with_seconds(Rates.f24(), round: :off)

      expected_message = "`seconds` is not cleanly divisible by `rate.playback`"

      assert :partial_frame == error.reason
      assert Framestamp.ParseError.message(error) == expected_message
    end
  end

  # Checks the results of non-raising parse methods.
  @spec check_parsed(Framestamp.parse_result(), map()) :: term()
  defp check_parsed(result, test_case) do
    assert {:ok, %Framestamp{} = parsed} = result
    check_parsed!(parsed, test_case)
  end

  # Checks the results of raising parse methods.
  @spec check_parsed!(Framestamp.t(), map()) :: term()
  defp check_parsed!(parsed, test_case) do
    assert %Framestamp{} = parsed
    assert parsed.seconds == test_case.seconds
    assert parsed.rate == test_case.rate
  end

  describe "smpte_midnight/1" do
    smpte_midnight_non_drop_table = [
      %{rate: Rates.f23_98()},
      %{rate: Rates.f29_97_ndf()},
      %{rate: Rates.f47_95()},
      %{rate: Rates.f59_94_ndf()}
    ]

    table_test "non-drop rate @ <%= rate %>", smpte_midnight_non_drop_table, test_case do
      %{rate: rate} = test_case

      assert {:ok, result} = Framestamp.smpte_midnight(rate)
      assert result.seconds == Ratio.new(432_432, 5)
      assert result == Framestamp.with_frames!("24:00:00:00", rate)
    end

    smpte_midnight_drop_table = [
      %{rate: Rates.f29_97_df()},
      %{rate: Rates.f59_94_df()}
    ]

    table_test "dop rate @ <%= rate %>", smpte_midnight_drop_table, test_case do
      %{rate: rate} = test_case

      assert {:ok, result} = Framestamp.smpte_midnight(rate)
      assert result.seconds == Ratio.new(53_999_946, 625)
      assert result == Framestamp.with_frames!("24:00:00:00", rate)
    end

    whole_frame_midnight_table = [
      %{rate: Rates.f24()},
      %{rate: Rates.f30()},
      %{rate: Rates.f48()},
      %{rate: Rates.f60()}
    ]

    table_test "whole-frame rate @ <%= rate %>", whole_frame_midnight_table, test_case do
      %{rate: rate} = test_case

      assert {:ok, result} = Framestamp.smpte_midnight(rate)
      assert result.seconds == Ratio.new(86_400, 1)
      assert result == Framestamp.with_frames!("24:00:00:00", rate)
    end

    non_smpte_midnight_table = [
      %{rate: Framerate.new!(Ratio.new(24_000, 1001))},
      %{rate: Framerate.new!(Ratio.new(30_000, 1001))}
    ]

    table_test "whole-frame rate @ <%= rate %>", non_smpte_midnight_table, test_case do
      %{rate: rate} = test_case
      assert {:error, %Framerate.InvalidSMPTEValueError{}} = Framestamp.smpte_midnight(rate)
    end
  end

  describe "smpte_midnight!/1" do
    test "raises on bad rate" do
      assert_raise Framerate.InvalidSMPTEValueError, fn ->
        rate = Framerate.new!(Ratio.new(24_000, 1001))
        Framestamp.smpte_midnight!(rate)
      end
    end
  end

  describe "#frames/2" do
    table_test "<%= name %>", parse_table, test_case do
      %{seconds: seconds, frames: frames, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      assert Framestamp.frames(input) == frames
    end

    @tag negate: @negate_fields
    table_test "<%= name %> | negative", parse_table, test_case do
      %{seconds: seconds, frames: frames, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      assert Framestamp.frames(input) == frames
    end

    test "round | :closest | implied" do
      framestamp = %Framestamp{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      assert Framestamp.frames(framestamp) == 24
    end

    test "round | :closest | explicit" do
      framestamp = %Framestamp{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      assert Framestamp.frames(framestamp, round: :closest) == 24
    end

    test "round | :closest | down" do
      framestamp = %Framestamp{seconds: Ratio.new(234, 240), rate: Rates.f24()}
      assert Framestamp.frames(framestamp) == 23
    end

    test "round | :floor" do
      framestamp = %Framestamp{seconds: Ratio.new(239, 240), rate: Rates.f24()}
      assert Framestamp.frames(framestamp, round: :floor) == 23
    end

    test "round | :ceil" do
      framestamp = %Framestamp{seconds: Ratio.new(231, 240), rate: Rates.f24()}
      assert Framestamp.frames(framestamp, round: :ceil) == 24
    end
  end

  describe "#timecode/2" do
    table_test "<%= name %>", parse_table, test_case do
      %{seconds: seconds, timecode: timecode, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      assert Framestamp.smpte_timecode(input) == timecode
    end

    @tag negate: @negate_fields
    table_test "<%= name %> | negative", parse_table, test_case do
      %{seconds: seconds, timecode: timecode, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      assert Framestamp.smpte_timecode(input) == timecode
    end

    test "round | :closest | implied" do
      framestamp = %Framestamp{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      assert Framestamp.smpte_timecode(framestamp) == "00:00:01:00"
    end

    test "round | :closest | explicit" do
      framestamp = %Framestamp{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      assert Framestamp.smpte_timecode(framestamp, round: :closest) == "00:00:01:00"
    end

    test "round | :closest | down" do
      framestamp = %Framestamp{seconds: Ratio.new(234, 240), rate: Rates.f24()}
      assert Framestamp.smpte_timecode(framestamp) == "00:00:00:23"
    end

    test "round | :floor" do
      framestamp = %Framestamp{seconds: Ratio.new(239, 240), rate: Rates.f24()}
      assert Framestamp.smpte_timecode(framestamp, round: :floor) == "00:00:00:23"
    end

    test "round | :ceil" do
      framestamp = %Framestamp{seconds: Ratio.new(231, 240), rate: Rates.f24()}
      assert Framestamp.smpte_timecode(framestamp, round: :ceil) == "00:00:01:00"
    end
  end

  describe "#runtime/2" do
    table_test "<%= name %>", parse_table, test_case do
      %{seconds: seconds, runtime: runtime, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      assert Framestamp.runtime(input) == runtime
    end

    @tag negate: @negate_fields
    table_test "<%= name %> | negative", parse_table, test_case do
      %{seconds: seconds, runtime: runtime, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      assert Framestamp.runtime(input) == runtime
    end

    test ":precision respected" do
      input = %Framestamp{seconds: Ratio.new(2_008_629_623, 24_000), rate: Rates.f23_98()}

      assert Framestamp.runtime(input, precision: 9) == "23:14:52.900958333"
      assert Framestamp.runtime(input, precision: 8) == "23:14:52.90095833"
      assert Framestamp.runtime(input, precision: 7) == "23:14:52.9009583"
      assert Framestamp.runtime(input, precision: 6) == "23:14:52.900958"
      assert Framestamp.runtime(input, precision: 5) == "23:14:52.90096"
      assert Framestamp.runtime(input, precision: 4) == "23:14:52.901"
      assert Framestamp.runtime(input, precision: 3) == "23:14:52.901"
      assert Framestamp.runtime(input, precision: 2) == "23:14:52.9"
      assert Framestamp.runtime(input, precision: 1) == "23:14:52.9"
    end

    test "trim_zeros?: false" do
      input = %Framestamp{seconds: Ratio.new(0), rate: Rates.f23_98()}
      assert Framestamp.runtime(input, trim_zeros?: false) == "00:00:00.000000000"
    end

    test "trim_zeros?: false, :precision respected" do
      input = %Framestamp{seconds: Ratio.new(2_008_629_623, 24_000), rate: Rates.f23_98()}

      assert Framestamp.runtime(input, precision: 9, trim_zeros?: false) == "23:14:52.900958333"
      assert Framestamp.runtime(input, precision: 8, trim_zeros?: false) == "23:14:52.90095833"
      assert Framestamp.runtime(input, precision: 7, trim_zeros?: false) == "23:14:52.9009583"
      assert Framestamp.runtime(input, precision: 6, trim_zeros?: false) == "23:14:52.900958"
      assert Framestamp.runtime(input, precision: 5, trim_zeros?: false) == "23:14:52.90096"
      assert Framestamp.runtime(input, precision: 4, trim_zeros?: false) == "23:14:52.9010"
      assert Framestamp.runtime(input, precision: 3, trim_zeros?: false) == "23:14:52.901"
      assert Framestamp.runtime(input, precision: 2, trim_zeros?: false) == "23:14:52.90"
      assert Framestamp.runtime(input, precision: 1, trim_zeros?: false) == "23:14:52.9"
    end
  end

  describe "#premiere_ticks/2" do
    table_test "<%= name %>", parse_table, test_case do
      %{seconds: seconds, premiere_ticks: premiere_ticks, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      assert Framestamp.premiere_ticks(input) == premiere_ticks
    end

    @tag negate: @negate_fields
    table_test "<%= name %> | negative", parse_table, test_case do
      %{seconds: seconds, premiere_ticks: premiere_ticks, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      assert Framestamp.premiere_ticks(input) == premiere_ticks
    end

    @one_quarter_tick Ratio.new(1, PremiereTicks.per_second() * 4)
    @one_half_tick Ratio.new(1, PremiereTicks.per_second() * 2)
    @three_quarter_tick Ratio.add(@one_half_tick, @one_quarter_tick)

    test "round | :closest | implied" do
      framestamp = %Framestamp{
        seconds: 1 |> Ratio.new() |> Ratio.add(@one_half_tick),
        rate: Rates.f24()
      }

      assert Framestamp.premiere_ticks(framestamp) == PremiereTicks.per_second() + 1
    end

    test "round | :closest | explicit" do
      framestamp = %Framestamp{
        seconds: 1 |> Ratio.new() |> Ratio.add(@one_half_tick),
        rate: Rates.f24()
      }

      expected = PremiereTicks.per_second() + 1
      assert Framestamp.premiere_ticks(framestamp, round: :closest) == expected
    end

    test "round | :closest | down" do
      framestamp = %Framestamp{
        seconds: 1 |> Ratio.new() |> Ratio.add(@one_quarter_tick),
        rate: Rates.f24()
      }

      assert Framestamp.premiere_ticks(framestamp, round: :closest) == PremiereTicks.per_second()
    end

    test "round | :floor" do
      framestamp = %Framestamp{
        seconds: 1 |> Ratio.new() |> Ratio.add(@three_quarter_tick),
        rate: Rates.f24()
      }

      assert Framestamp.premiere_ticks(framestamp, round: :floor) == PremiereTicks.per_second()
    end

    test "round | :ceil" do
      framestamp = %Framestamp{
        seconds: 1 |> Ratio.new() |> Ratio.add(@one_quarter_tick),
        rate: Rates.f24()
      }

      expected = PremiereTicks.per_second() + 1
      assert Framestamp.premiere_ticks(framestamp, round: :ceil) == expected
    end

    test "round: :off raises" do
      framestamp = %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}

      exception = assert_raise ArgumentError, fn -> Framestamp.premiere_ticks(framestamp, round: :off) end
      assert Exception.message(exception) == "`:round` cannot be `:off`"
    end
  end

  describe "#feet_and_frames/2" do
    table_test "<%= name %> | 35mm, 4perf", parse_table, test_case do
      %{seconds: seconds, feet_and_frames_35mm_4perf: expected, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      result = input |> Framestamp.feet_and_frames() |> String.Chars.to_string()
      assert result == expected
    end

    @tag negate: @negate_fields
    table_test "<%= name %> | 35mm, 4perf | negative", parse_table, test_case do
      %{seconds: seconds, feet_and_frames_35mm_4perf: expected, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      result = input |> Framestamp.feet_and_frames() |> String.Chars.to_string()
      assert result == expected
    end

    table_test "<%= name %> | 35mm, 4perf | explicit", parse_table, test_case do
      %{seconds: seconds, feet_and_frames_35mm_4perf: expected, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      result = input |> Framestamp.feet_and_frames(film_format: :ff35mm_4perf) |> String.Chars.to_string()
      assert result == expected
    end

    @tag negate: @negate_fields
    table_test "<%= name %> | 35mm, 4perf | explicit | negative", parse_table, test_case do
      %{seconds: seconds, feet_and_frames_35mm_4perf: expected, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      result = input |> Framestamp.feet_and_frames(film_format: :ff35mm_4perf) |> String.Chars.to_string()
      assert result == expected
    end

    table_test "<%= name %> | 35mm, 2perf", parse_table, test_case do
      %{seconds: seconds, feet_and_frames_35mm_2perf: expected, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      result = input |> Framestamp.feet_and_frames(film_format: :ff35mm_2perf) |> String.Chars.to_string()
      assert result == expected
    end

    @tag negate: @negate_fields
    table_test "<%= name %> | 35mm, 2perf | negative", parse_table, test_case do
      %{seconds: seconds, feet_and_frames_35mm_2perf: expected, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      result = input |> Framestamp.feet_and_frames(film_format: :ff35mm_2perf) |> String.Chars.to_string()
      assert result == expected
    end

    table_test "<%= name %> | 16mm", parse_table, test_case do
      %{seconds: seconds, feet_and_frames_16mm: expected, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      result = input |> Framestamp.feet_and_frames(film_format: :ff16mm) |> String.Chars.to_string()
      assert result == expected
    end

    @tag negate: @negate_fields
    table_test "<%= name %> | 16mm | negative", parse_table, test_case do
      %{seconds: seconds, feet_and_frames_16mm: expected, rate: rate} = test_case
      input = %Framestamp{seconds: seconds, rate: rate}

      result = input |> Framestamp.feet_and_frames(film_format: :ff16mm) |> String.Chars.to_string()
      assert result == expected
    end

    test "round | :closest | implied" do
      framestamp = %Framestamp{seconds: Ratio.new(235, 240), rate: Rates.f24()}

      result = framestamp |> Framestamp.feet_and_frames() |> String.Chars.to_string()
      assert result == "1+08"
    end

    test "round | :closest | explicit" do
      framestamp = %Framestamp{seconds: Ratio.new(235, 240), rate: Rates.f24()}

      result = framestamp |> Framestamp.feet_and_frames(round: :closest) |> String.Chars.to_string()
      assert result == "1+08"
    end

    test "round | :closest | down" do
      framestamp = %Framestamp{seconds: Ratio.new(234, 240), rate: Rates.f24()}

      result = framestamp |> Framestamp.feet_and_frames(round: :closest) |> String.Chars.to_string()
      assert result == "1+07"
    end

    test "round | :floor" do
      framestamp = %Framestamp{seconds: Ratio.new(239, 240), rate: Rates.f24()}

      result = framestamp |> Framestamp.feet_and_frames(round: :floor) |> String.Chars.to_string()
      assert result == "1+07"
    end

    test "round | :ceil" do
      framestamp = %Framestamp{seconds: Ratio.new(231, 240), rate: Rates.f24()}

      result = framestamp |> Framestamp.feet_and_frames(round: :ceil) |> String.Chars.to_string()
      assert result == "1+08"
    end

    test "round: :off raises" do
      framestamp = %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}

      exception = assert_raise ArgumentError, fn -> Framestamp.feet_and_frames(framestamp, round: :off) end
      assert Exception.message(exception) == "`:round` cannot be `:off`"
    end
  end

  describe "#with_frames/2 - malformed tc" do
    malformed_tc_table = [
      %{
        val_in: "00:59:59:24",
        expected: "01:00:00:00"
      },
      %{
        val_in: "00:59:59:28",
        expected: "01:00:00:04"
      },
      %{
        val_in: "00:00:62:04",
        expected: "00:01:02:04"
      },
      %{
        val_in: "00:62:01:04",
        expected: "01:02:01:04"
      },
      %{
        val_in: "00:62:62:04",
        expected: "01:03:02:04"
      },
      %{
        val_in: "123:00:00:00",
        expected: "123:00:00:00"
      },
      %{
        val_in: "01:00:00:48",
        expected: "01:00:02:00"
      },
      %{
        val_in: "01:00:120:00",
        expected: "01:02:00:00"
      },
      %{
        val_in: "01:120:00:00",
        expected: "03:00:00:00"
      }
    ]

    table_test "<%= val_in %> == <%= expected %>", malformed_tc_table, test_case do
      %{val_in: val_in, expected: expected} = test_case

      parsed = Framestamp.with_frames!(val_in, Rates.f23_98())
      assert Framestamp.smpte_timecode(parsed) == expected
    end
  end

  describe "#with_frames/2 - partial tc" do
    partial_tc_table = [
      %{
        val_in: "1:02:03:04",
        expected: "01:02:03:04"
      },
      %{
        val_in: "02:03:04",
        expected: "00:02:03:04"
      },
      %{
        val_in: "2:03:04",
        expected: "00:02:03:04"
      },
      %{
        val_in: "03:04",
        expected: "00:00:03:04"
      },
      %{
        val_in: "3:04",
        expected: "00:00:03:04"
      },
      %{
        val_in: "04",
        expected: "00:00:00:04"
      },
      %{
        val_in: "4",
        expected: "00:00:00:04"
      }
    ]

    table_test "<%= val_in %> == <%= expected %>", partial_tc_table, test_case do
      %{val_in: val_in, expected: expected} = test_case

      parsed = Framestamp.with_frames!(val_in, Rates.f23_98())
      assert expected == Framestamp.smpte_timecode(parsed)
    end
  end

  describe "#with_seconds/3 - partial runtime" do
    partial_runtime_table = [
      %{
        val_in: "1:02:03.5",
        expected: "01:02:03.5"
      },
      %{
        val_in: "02:03.5",
        expected: "00:02:03.5"
      },
      %{
        val_in: "2:03.5",
        expected: "00:02:03.5"
      },
      %{
        val_in: "03.5",
        expected: "00:00:03.5"
      },
      %{
        val_in: "3.5",
        expected: "00:00:03.5"
      },
      %{
        val_in: "0.5",
        expected: "00:00:00.5"
      }
    ]

    table_test "<%= val_in %> == <%= expected %>", partial_runtime_table, test_case do
      %{val_in: val_in, expected: expected} = test_case

      parsed = Framestamp.with_seconds!(val_in, Rates.f24())
      assert expected == Framestamp.runtime(parsed)
    end
  end

  describe "String.Chars.to_string/1" do
    test "renders expected for non-drop" do
      stamp = Framestamp.with_frames!(24, Rates.f23_98())
      assert String.Chars.to_string(stamp) == "<00:00:01:00 <23.98 NTSC>>"
    end

    test "renders with `;` frames sep for drop-frame" do
      stamp = Framestamp.with_frames!(30, Rates.f29_97_df())
      assert String.Chars.to_string(stamp) == "<00:00:01;00 <29.97 NTSC DF>>"
    end
  end

  describe "Inspect.inspect/2" do
    test "renders expected for non-drop" do
      stamp = Framestamp.with_frames!(24, Rates.f23_98())
      assert Inspect.inspect(stamp, Inspect.Opts.new([])) == "<00:00:01:00 <23.98 NTSC>>"
    end

    test "renders with `;` frames sep for drop-frame" do
      stamp = Framestamp.with_frames!(30, Rates.f29_97_df())
      assert Inspect.inspect(stamp, Inspect.Opts.new([])) == "<00:00:01;00 <29.97 NTSC DF>>"
    end
  end
end
