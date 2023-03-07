defmodule Vtc.TimecodeTest.TcParseCase do
  @moduledoc false

  alias Vtc.Sources.Frames
  alias Vtc.Sources.Seconds

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
          seconds_inputs: [Seconds.t()],
          frames_inputs: [Frames.t()],
          seconds: Ratio.t(),
          frames: integer(),
          timecode: String.t(),
          runtime: String.t(),
          premiere_ticks: integer(),
          feet_and_frames: String.t()
        }
end

defmodule Vtc.TimecodeTest.ParseHelpers do
  @moduledoc false

  alias Vtc.Timecode
  alias Vtc.TimecodeTest.TcParseCase

  @spec make_negative_case(TcParseCase.t()) :: TcParseCase.t()
  def make_negative_case(%TcParseCase{frames: 0} = test_case), do: test_case

  def make_negative_case(test_case) do
    %{
      test_case
      | seconds: Ratio.negate(test_case.seconds),
        frames: -test_case.frames,
        timecode: "-" <> test_case.timecode,
        runtime: "-" <> test_case.runtime,
        premiere_ticks: -test_case.premiere_ticks,
        feet_and_frames: "-" <> test_case.feet_and_frames
    }
  end

  @spec make_negative_input(input) :: input when [input: String.t() | Rational.t()]
  def make_negative_input(input) when is_binary(input), do: "-" <> input
  def make_negative_input(input), do: Ratio.negate(input)
end

defmodule Vtc.TimecodeTest do
  @moduledoc false

  use ExUnit.Case
  use ExUnitProperties

  alias Vtc.Framerate
  alias Vtc.Rates
  alias Vtc.Timecode

  alias Vtc.TimecodeTest.ParseHelpers
  alias Vtc.TimecodeTest.TcParseCase

  doctest Vtc.Timecode

  @parse_cases [
    # 23.98 NTSC #########################
    ######################################
    %TcParseCase{
      name: "01:00:00:00 @ 23.98 NTSC",
      rate: Rates.f23_98(),
      seconds_inputs: [
        Ratio.new(18_018, 5),
        3603.6,
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
      rate: Rates.f23_98(),
      seconds_inputs: [
        Ratio.new(12_012, 5),
        2402.4,
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
    # 24 True ############################
    ######################################
    %TcParseCase{
      name: "01:00:00:00 @ 24",
      rate: Rates.f24(),
      seconds_inputs: [
        3600,
        "01:00:00.0"
      ],
      frames_inputs: [
        86_400,
        "01:00:00:00",
        "5400+00"
      ],
      seconds: Ratio.new(3600, 1),
      frames: 86_400,
      timecode: "01:00:00:00",
      runtime: "01:00:00.0",
      premiere_ticks: 914_457_600_000_000,
      feet_and_frames: "5400+00"
    },
    # 29.97 Drop #########################
    ######################################
    %TcParseCase{
      name: "00:00:00;00 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
      seconds_inputs: [
        0,
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
      name: "00:01:01;00 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
      seconds_inputs: [
        Ratio.new(457_457, 7500),
        "00:01:00.994266667"
      ],
      frames_inputs: [
        1828,
        "00:01:01;00",
        "114+04"
      ],
      seconds: Ratio.new(457_457, 7500),
      frames: 1828,
      timecode: "00:01:01;00",
      runtime: "00:01:00.994266667",
      premiere_ticks: 15_493_519_641_600,
      feet_and_frames: "114+04"
    },
    %TcParseCase{
      name: "00:00:02;02 29.97 Drop-Frame",
      rate: Rates.f29_97_df(),
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
      rate: Rates.f29_97_df(),
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
      rate: Rates.f29_97_df(),
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
      rate: Rates.f29_97_df(),
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
      rate: Rates.f29_97_df(),
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
      rate: Rates.f29_97_df(),
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
      rate: Rates.f59_94_df(),
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
      rate: Rates.f59_94_df(),
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
      rate: Rates.f59_94_df(),
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
      rate: Rates.f59_94_df(),
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

  describe "#with_seconds/2" do
    for test_case <- @parse_cases do
      @test_case test_case
      @test_case_negative ParseHelpers.make_negative_case(test_case)

      for input_case <- @test_case.seconds_inputs do
        @input_case input_case
        @negative_input ParseHelpers.make_negative_input(@input_case)

        test "#{@test_case.name} | #{@input_case} | #{@test_case.rate}" do
          @input_case
          |> Timecode.with_seconds(@test_case.rate)
          |> check_parsed(@test_case)
        end

        test "#{@test_case.name} | #{@input_case} | #{@test_case.rate} | negative" do
          @negative_input
          |> Timecode.with_seconds(@test_case_negative.rate)
          |> check_parsed(@test_case_negative)
        end
      end
    end

    test "ParseTimecodeError when bad format" do
      {:error, %Timecode.ParseError{} = error} =
        Timecode.with_seconds("notatimecode", Rates.f24())

      assert :unrecognized_format == error.reason
      assert "string format not recognized" = Timecode.ParseError.message(error)
    end
  end

  describe "#with_seconds!/1" do
    for test_case <- @parse_cases do
      @test_case test_case
      @test_case_negative ParseHelpers.make_negative_case(test_case)

      for input_case <- @test_case.seconds_inputs do
        @input_case input_case
        @negative_input ParseHelpers.make_negative_input(@input_case)

        test "#{@test_case.name} | #{@input_case} | #{@test_case.rate}" do
          @input_case
          |> Timecode.with_seconds!(@test_case.rate)
          |> check_parsed!(@test_case)
        end

        test "#{@test_case.name}! | #{@input_case} | #{@test_case.rate} | negative" do
          @negative_input
          |> Timecode.with_seconds!(@test_case_negative.rate)
          |> check_parsed!(@test_case_negative)
        end
      end
    end

    test "ParseTimecodeError throws" do
      assert_raise Timecode.ParseError, fn ->
        Timecode.with_seconds!("notatimecode", Rates.f24())
      end
    end
  end

  describe "#with_frames/2" do
    @describetag with_frames: true

    for {test_case, case_index} <- Enum.with_index(@parse_cases) do
      @test_case test_case
      @test_case_negative ParseHelpers.make_negative_case(test_case)

      for {input_case, input_index} <- Enum.with_index(@test_case.frames_inputs) do
        @input_case input_case
        @negative_input ParseHelpers.make_negative_input(input_case)

        @tag case: :"with_frames_#{case_index}_#{input_index}"
        test "#{@test_case.name} | #{case_index}:#{input_index} | #{@input_case} | #{@test_case.rate}" do
          @input_case
          |> Timecode.with_frames(@test_case.rate)
          |> check_parsed(@test_case)
        end

        @tag case: :"with_frames_#{case_index}_#{input_index}_negative"
        test "#{@test_case.name}! | #{case_index}:#{input_index} | #{@input_case} | #{@test_case.rate} | negative" do
          @negative_input
          |> Timecode.with_frames(@test_case_negative.rate)
          |> check_parsed(@test_case_negative)
        end
      end
    end

    test "ParseTimecodeError - Format" do
      assert {:error, %Timecode.ParseError{} = error} =
               Timecode.with_frames("notatimecode", Rates.f24())

      assert :unrecognized_format == error.reason
      assert "string format not recognized" = Timecode.ParseError.message(error)
    end

    test "ParseTimecodeError - Bad Drop Frame" do
      assert {:error, %Timecode.ParseError{} = error} =
               Timecode.with_frames("00:01:00;01", Rates.f29_97_df())

      assert :bad_drop_frames == error.reason

      assert "frames value not allowed for drop-frame timecode. frame should have been dropped" =
               Timecode.ParseError.message(error)
    end
  end

  describe "#with_frames!/1" do
    for test_case <- @parse_cases do
      @test_case test_case
      @test_case_negative ParseHelpers.make_negative_case(test_case)

      for input_case <- @test_case.frames_inputs do
        @input_case input_case
        @negative_input ParseHelpers.make_negative_input(input_case)

        test "#{@test_case.name} | #{@input_case} | #{@test_case.rate}" do
          @input_case
          |> Timecode.with_frames!(@test_case.rate)
          |> check_parsed!(@test_case)
        end

        test "#{@test_case.name}! | #{@input_case} | #{@test_case.rate} | negative" do
          @negative_input
          |> Timecode.with_frames!(@test_case_negative.rate)
          |> check_parsed!(@test_case_negative)
        end
      end
    end

    test "ParseTimecodeError throws" do
      assert_raise Timecode.ParseError, fn ->
        Timecode.with_frames!("notatimecode", Rates.f24())
      end
    end
  end

  describe "#with_premiere_ticks/2" do
    for test_case <- @parse_cases do
      @test_case test_case
      @test_case_negative ParseHelpers.make_negative_case(test_case)

      test "#{@test_case.name} | #{@test_case.premiere_ticks} | #{@test_case.rate}" do
        @test_case.premiere_ticks
        |> Timecode.with_premiere_ticks(@test_case.rate)
        |> check_parsed(@test_case)
      end

      test "#{@test_case.name}! | #{@test_case.premiere_ticks} | #{@test_case.rate} | negative" do
        @test_case.premiere_ticks
        |> ParseHelpers.make_negative_input()
        |> Timecode.with_premiere_ticks(@test_case_negative.rate)
        |> check_parsed(@test_case_negative)
      end
    end
  end

  describe "#with_premiere_ticks!/2" do
    for test_case <- @parse_cases do
      @test_case test_case
      @test_case_negative ParseHelpers.make_negative_case(test_case)

      test "#{@test_case.name} | #{@test_case.premiere_ticks} | #{@test_case.rate}" do
        @test_case.premiere_ticks
        |> Timecode.with_premiere_ticks!(@test_case.rate)
        |> check_parsed!(@test_case)
      end

      test "#{@test_case.name}! | #{@test_case.premiere_ticks} | #{@test_case.rate} | negative" do
        @test_case.premiere_ticks
        |> ParseHelpers.make_negative_input()
        |> Timecode.with_premiere_ticks!(@test_case_negative.rate)
        |> check_parsed!(@test_case_negative)
      end
    end
  end

  # Checks the results of non-raising parse methods.
  @spec check_parsed(Timecode.parse_result(), TcParseCase.t()) :: term()
  defp check_parsed(result, test_case) do
    assert {:ok, %Timecode{} = parsed} = result
    check_parsed!(parsed, test_case)
  end

  # Checks the results of raising parse methods.
  @spec check_parsed!(Timecode.t(), TcParseCase.t()) :: term()
  defp check_parsed!(parsed, test_case) do
    assert %Timecode{} = parsed
    assert parsed.seconds == test_case.seconds
    assert parsed.rate == test_case.rate
  end

  describe "#frames/1" do
    for test_case <- @parse_cases do
      @test_case test_case
      @input_struct %Timecode{seconds: @test_case.seconds, rate: @test_case.rate}

      @test_case_negative ParseHelpers.make_negative_case(test_case)
      @input_struct_negative %Timecode{
        seconds: @test_case_negative.seconds,
        rate: @test_case_negative.rate
      }

      test "#{@test_case.name}" do
        assert Timecode.frames(@input_struct) == @test_case.frames
      end

      test "#{@test_case.name} | negative" do
        assert Timecode.frames(@input_struct_negative) == @test_case_negative.frames
      end
    end
  end

  describe "#timecode/1" do
    for {test_case, case_index} <- Enum.with_index(@parse_cases) do
      @test_case test_case
      @input_struct %Timecode{seconds: @test_case.seconds, rate: @test_case.rate}

      @test_case_negative ParseHelpers.make_negative_case(test_case)
      @input_struct_negative %Timecode{
        seconds: @test_case_negative.seconds,
        rate: @test_case_negative.rate
      }

      @tag case: :"timecode_#{case_index}"
      test "#{@test_case.name} | #{case_index}" do
        assert Timecode.timecode(@input_struct) == @test_case.timecode
      end

      @tag case: :"timecode_#{case_index}_negative"
      test "#{@test_case.name} | #{case_index} | negative" do
        assert Timecode.timecode(@input_struct_negative) == @test_case_negative.timecode
      end
    end
  end

  describe "#runtime/1" do
    for test_case <- @parse_cases do
      @test_case test_case
      @input_struct %Timecode{seconds: @test_case.seconds, rate: @test_case.rate}

      @test_case_negative ParseHelpers.make_negative_case(test_case)
      @input_struct_negative %Timecode{
        seconds: @test_case_negative.seconds,
        rate: @test_case_negative.rate
      }

      test "#{@test_case.name}" do
        assert Timecode.runtime(@input_struct, 9) == @test_case.runtime
      end

      test "#{@test_case.name} | negative" do
        assert Timecode.runtime(@input_struct_negative, 9) == @test_case_negative.runtime
      end
    end
  end

  describe "#premiere_ticks/1" do
    for test_case <- @parse_cases do
      @test_case test_case
      @input_struct %Timecode{seconds: @test_case.seconds, rate: @test_case.rate}

      @test_case_negative ParseHelpers.make_negative_case(test_case)
      @input_struct_negative %Timecode{
        seconds: @test_case_negative.seconds,
        rate: @test_case_negative.rate
      }

      test "#{@test_case.name}" do
        assert Timecode.premiere_ticks(@input_struct) == @test_case.premiere_ticks
      end

      test "#{@test_case.name} | negative" do
        assert Timecode.premiere_ticks(@input_struct_negative) ==
                 @test_case_negative.premiere_ticks
      end
    end
  end

  describe "#feet_and_frames/1" do
    for test_case <- @parse_cases do
      @test_case test_case
      @input_struct %Timecode{seconds: @test_case.seconds, rate: @test_case.rate}

      @test_case_negative ParseHelpers.make_negative_case(test_case)
      @input_struct_negative %Timecode{
        seconds: @test_case_negative.seconds,
        rate: @test_case_negative.rate
      }

      test "#{@test_case.name}" do
        assert Timecode.feet_and_frames(@input_struct) == @test_case.feet_and_frames
      end

      test "#{@test_case.name} | negative" do
        assert Timecode.feet_and_frames(@input_struct_negative) ==
                 @test_case_negative.feet_and_frames
      end
    end
  end

  describe "#with_frames/2 - malformed tc" do
    @malformed_cases [
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

    for test_case <- @malformed_cases do
      @test_case test_case

      test "#{@test_case.val_in} == #{@test_case.expected}" do
        parsed = Timecode.with_frames!(@test_case.val_in, Rates.f23_98())
        assert @test_case.expected == Timecode.timecode(parsed)
      end
    end
  end

  describe "#with_frames/2 - partial tc" do
    @partial_tc_cases [
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

    for test_case <- @partial_tc_cases do
      @test_case test_case

      test "#{@test_case.val_in} == #{@test_case.expected}" do
        parsed = Timecode.with_frames!(@test_case.val_in, Rates.f23_98())
        assert @test_case.expected == Timecode.timecode(parsed)
      end
    end
  end

  describe "#with_seconds/2 - partial runtime" do
    @partial_runtime_cases [
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

    for test_case <- @partial_runtime_cases do
      @test_case test_case

      test "#{@test_case.val_in} == #{@test_case.expected}" do
        parsed = Timecode.with_seconds!(@test_case.val_in, Rates.f24())
        assert @test_case.expected == Timecode.runtime(parsed, 9)
      end
    end
  end

  describe "#compare/2" do
    @test_cases [
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        expected: :eq
      },
      %{
        a: Timecode.with_frames!("00:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        expected: :lt
      },
      %{
        a: Timecode.with_frames!("-01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        expected: :lt
      },
      %{
        a: Timecode.with_frames!("02:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        expected: :gt
      },
      %{
        a: Timecode.with_frames!("02:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("00:00:00:00", Rates.f23_98()),
        expected: :gt
      },
      %{
        a: Timecode.with_frames!("02:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("-01:00:00:00", Rates.f23_98()),
        expected: :gt
      },
      %{
        a: Timecode.with_frames!("00:00:59:23", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        expected: :lt
      },
      %{
        a: Timecode.with_frames!("01:00:00:01", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        expected: :gt
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f24()),
        expected: :gt
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f59_94_ndf()),
        expected: :eq
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f59_94_df()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f59_94_ndf()),
        expected: :lt
      }
    ]

    for test_case <- @test_cases do
      @test_case test_case

      test "#{@test_case.a} is #{@test_case.expected} #{@test_case.b}" do
        %{a: a, b: b, expected: expected} = @test_case
        assert Timecode.compare(a, b) == expected
      end

      if @test_case.a.rate == @test_case.b.rate do
        test "#{@test_case.a} is #{@test_case.expected} #{@test_case.b} | b = tc string" do
          %{a: a, b: b, expected: expected} = @test_case
          assert Timecode.compare(a, Timecode.timecode(b)) == expected
        end

        test "#{@test_case.a} is #{@test_case.expected} #{@test_case.b} | b = frames int" do
          %{a: a, b: b, expected: expected} = @test_case
          assert Timecode.compare(a, Timecode.frames(b)) == expected
        end
      end
    end

    property "if a.rate = b.rate then a and b comparison should equal the comparison of their frame count" do
      check all(
              [a_frames, b_frames] <- StreamData.list_of(StreamData.integer(), length: 2),
              rate_x <- StreamData.integer(1..240),
              ntsc <- StreamData.boolean(),
              max_runs: 100
            ) do
        ntsc = if ntsc, do: :non_drop, else: nil
        rate = Framerate.new!(rate_x, ntsc, false)

        a = Timecode.with_frames!(a_frames, rate)
        b = Timecode.with_frames!(b_frames, rate)

        expected =
          cond do
            a_frames == b_frames -> :eq
            a_frames < b_frames -> :lt
            true -> :gt
          end

        assert Timecode.compare(a, b) == expected
      end
    end
  end

  @rebase_cases [
    %{
      original: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
      new_rate: Rates.f47_95(),
      expected: Timecode.with_frames!("00:30:00:00", Rates.f47_95())
    },
    %{
      original: Timecode.with_frames!("01:00:00:00", Rates.f47_95()),
      new_rate: Rates.f23_98(),
      expected: Timecode.with_frames!("02:00:00:00", Rates.f23_98())
    },
    %{
      original: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
      new_rate: Rates.f24(),
      expected: Timecode.with_frames!("01:00:00:00", Rates.f24())
    },
    %{
      original: Timecode.with_frames!("01:00:00;00", Rates.f29_97_df()),
      new_rate: Rates.f29_97_ndf(),
      expected: Timecode.with_frames!("00:59:56;12", Rates.f29_97_ndf())
    },
    %{
      original: Timecode.with_frames!("01:00:00;00", Rates.f59_94_df()),
      new_rate: Rates.f59_94_ndf(),
      expected: Timecode.with_frames!("00:59:56;24", Rates.f59_94_ndf())
    }
  ]

  describe "rebase/2" do
    for rebase_case <- @rebase_cases do
      @rebase_case rebase_case

      test "#{@rebase_case.original} -> #{@rebase_case.new_rate}" do
        %{original: original, new_rate: new_rate, expected: expected} = @rebase_case
        assert {:ok, rebased} = Timecode.rebase(original, new_rate)
        assert rebased == expected

        assert {:ok, round_tripped} = Timecode.rebase(rebased, original.rate)
        assert round_tripped == original
      end
    end

    property "round trip rebases do not lose accuracy" do
      run_rebase_property_test(fn timecode, new_rate ->
        assert {:ok, rebased} = Timecode.rebase(timecode, new_rate)
        rebased
      end)
    end
  end

  describe "rebase!/2" do
    for rebase_case <- @rebase_cases do
      @rebase_case rebase_case

      test "#{@rebase_case.original} -> #{@rebase_case.new_rate}" do
        %{original: original, new_rate: new_rate, expected: expected} = @rebase_case
        assert %Timecode{} = rebased = Timecode.rebase!(original, new_rate)
        assert rebased == expected

        assert %Timecode{} = round_tripped = Timecode.rebase!(rebased, original.rate)
        assert round_tripped == original
      end
    end

    property "round trip rebases do not lose accuracy" do
      run_rebase_property_test(fn timecode, new_rate ->
        Timecode.rebase!(timecode, new_rate)
      end)
    end
  end

  @spec run_rebase_property_test((Timecode.t(), Framerate.t() -> Timecode.t())) :: term()
  defp run_rebase_property_test(do_reabase) do
    check all(
            frames <- StreamData.integer(),
            original_rate_x <- StreamData.integer(1..240),
            original_ntsc <- StreamData.boolean(),
            target_rate_x <- StreamData.integer(1..240),
            target_ntsc <- StreamData.boolean(),
            max_runs: 20
          ) do
      original_ntsc = if original_ntsc, do: :non_drop, else: nil
      origina_rate = Framerate.new!(original_rate_x, original_ntsc, false)

      target_ntsc = if target_ntsc, do: :non_drop, else: nil
      target_rate = Framerate.new!(target_rate_x, target_ntsc, false)

      original = Timecode.with_frames!(frames, origina_rate)

      rebased = do_reabase.(original, target_rate)
      round_trip = do_reabase.(rebased, origina_rate)
      assert round_trip == original
    end
  end

  property "drop frame round trip" do
    check all(
            rate_multiplier <- StreamData.integer(1..10),
            timecode_values <- create_drop_frame_timecode_generator(rate_multiplier),
            rate <- (30 * rate_multiplier) |> Framerate.new!(:drop) |> StreamData.constant(),
            max_runs: 100
          ) do
      %{
        timecode_string: timecode_string,
        minutes: minutes,
        seconds: seconds,
        frames: frames
      } = timecode_values

      timecode = Timecode.with_frames!(timecode_string, rate)

      if frames < 2 * rate_multiplier and rem(minutes, 10) != 0 and seconds == 0 do
        assert_raise Timecode.ParseError, fn -> Timecode.timecode(timecode) end
      else
        assert Timecode.timecode(timecode) == timecode_string
      end
    end
  end

  @spec create_drop_frame_timecode_generator(non_neg_integer()) :: map()
  defp create_drop_frame_timecode_generator(rate_multiplier) do
    StreamData.map(
      {
        StreamData.integer(1..23),
        StreamData.integer(0..59),
        StreamData.integer(0..59),
        StreamData.integer(0..(30 * rate_multiplier - 1)),
        StreamData.boolean()
      },
      fn {hours, seconds, minutes, frames, negative?} ->
        timecode_string =
          [hours, seconds, minutes, frames]
          |> Enum.map(&Integer.to_string/1)
          |> Enum.map(&String.pad_leading(&1, 2, "0"))
          |> Enum.intersperse(":")
          |> List.replace_at(-2, ";")
          |> List.to_string()

        timecode_string = if negative?, do: "-" <> timecode_string, else: timecode_string

        %{
          timecode_string: timecode_string,
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          frames: frames
        }
      end
    )
  end
end
