defmodule Vtc.TimecodeTest.ParseHelpers do
  @moduledoc false

  alias Vtc.Source.PremiereTicks
  alias Vtc.Timecode

  # Functions used during macro expansion compilation cannot be declared in the same
  # module, so these helpers need to live here.

  @spec make_negative_case(map()) :: map()
  def make_negative_case(%{frames: 0} = test_case), do: test_case

  def make_negative_case(test_case) do
    %{
      test_case
      | seconds: Ratio.minus(test_case.seconds),
        frames: -test_case.frames,
        timecode: "-" <> test_case.timecode,
        runtime: "-" <> test_case.runtime,
        premiere_ticks: -test_case.premiere_ticks,
        feet_and_frames: "-" <> test_case.feet_and_frames
    }
  end

  @spec make_negative_input(input) :: input when [input: String.t() | Ratio.t()]
  def make_negative_input(input) when is_binary(input), do: "-" <> input
  def make_negative_input(%Ratio{} = input), do: Ratio.minus(input)
  def make_negative_input(%PremiereTicks{in: val}), do: %PremiereTicks{in: -val}
  def make_negative_input(input), do: -input
end

defmodule Vtc.TimecodeTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Vtc.Rates
  alias Vtc.Source.PremiereTicks
  alias Vtc.Timecode
  alias Vtc.Utils.Consts

  alias Vtc.TimecodeTest.ParseHelpers

  @parse_cases [
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
        "5400+00"
      ],
      seconds: Ratio.new(18_018, 5),
      frames: 86_400,
      timecode: "01:00:00:00",
      runtime: "01:00:03.6",
      premiere_ticks: 915_372_057_600_000,
      feet_and_frames: "5400+00"
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
        "0+00"
      ],
      seconds: Ratio.new(0, 1),
      frames: 0,
      timecode: "00:00:00;00",
      runtime: "00:00:00.0",
      premiere_ticks: 0,
      feet_and_frames: "0+00"
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
        "114+04"
      ],
      seconds: Ratio.new(457_457, 7500),
      frames: 1828,
      timecode: "00:01:01;00",
      runtime: "00:01:00.994266667",
      premiere_ticks: 15_493_519_641_600,
      feet_and_frames: "114+04"
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
        "3+14"
      ],
      seconds: Ratio.new(31_031, 15_000),
      frames: 62,
      timecode: "00:00:02;02",
      runtime: "00:00:02.068733333",
      premiere_ticks: 525_491_366_400,
      feet_and_frames: "3+14"
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
        "112+08"
      ],
      seconds: Ratio.new(3003, 50),
      frames: 1800,
      timecode: "00:01:00;02",
      runtime: "00:01:00.06",
      premiere_ticks: 15_256_200_960_000,
      feet_and_frames: "112+08"
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
        "224+14"
      ],
      seconds: Ratio.new(1_800_799, 15_000),
      frames: 3598,
      timecode: "00:02:00;02",
      runtime: "00:02:00.053266667",
      premiere_ticks: 30_495_450_585_600,
      feet_and_frames: "224+14"
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
        "1123+14"
      ],
      seconds: Ratio.new(2_999_997, 5000),
      frames: 17_982,
      timecode: "00:10:00;00",
      runtime: "00:09:59.9994",
      premiere_ticks: 152_409_447_590_400,
      feet_and_frames: "1123+14"
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
        "1236+06"
      ],
      seconds: Ratio.new(3_300_297, 5000),
      frames: 19_782,
      timecode: "00:11:00;02",
      runtime: "00:11:00.0594",
      premiere_ticks: 167_665_648_550_400,
      feet_and_frames: "1236+06"
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
    %{
      name: "00:00:00;00 59.94 Drop-Frame",
      rate: Rates.f59_94_df(),
      seconds_inputs: [
        Ratio.new(0, 1),
        0.0,
        "00:00:00.0",
        %PremiereTicks{in: 0}
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
        "3+13"
      ],
      seconds: Ratio.new(61_061, 60_000),
      frames: 61,
      timecode: "00:00:01;01",
      runtime: "00:00:01.017683333",
      premiere_ticks: 258_507_849_600,
      feet_and_frames: "3+13"
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
        "3+15"
      ],
      seconds: Ratio.new(21_021, 20_000),
      frames: 63,
      timecode: "00:00:01;03",
      runtime: "00:00:01.05105",
      premiere_ticks: 266_983_516_800,
      feet_and_frames: "3+15"
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

  describe "#with_seconds/3" do
    for {test_case, test_index} <- Enum.with_index(@parse_cases) do
      @test_case test_case
      @test_case_negative ParseHelpers.make_negative_case(test_case)

      for {input_case, case_index} <- Enum.with_index(@test_case.seconds_inputs) do
        @input_case input_case
        @negative_input ParseHelpers.make_negative_input(input_case)

        @tag case: :"with_seconds_#{test_index}_#{case_index}"
        test "#{@test_case.name} | #{test_index}-#{case_index} | #{inspect(@input_case)} | #{@test_case.rate}" do
          @input_case
          |> Timecode.with_seconds(@test_case.rate)
          |> check_parsed(@test_case)
        end

        @tag case: :"with_seconds_#{test_index}_#{case_index}_negative"
        test "#{@test_case.name} | #{test_index}-#{case_index} | #{inspect(@input_case)} | #{@test_case.rate} | negative" do
          @negative_input
          |> Timecode.with_seconds(@test_case_negative.rate)
          |> check_parsed(@test_case_negative)
        end
      end
    end

    test "round | :closest | implied" do
      {:ok, result} = Timecode.with_seconds(Ratio.new(239, 240), Rates.f24())
      assert result == %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
    end

    test "round | :closest | explicit" do
      {:ok, result} = Timecode.with_seconds(Ratio.new(239, 240), Rates.f24(), round: :closest)
      assert result == %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
    end

    test "round | :closest | down" do
      {:ok, result} = Timecode.with_seconds(Ratio.new(234, 240), Rates.f24(), round: :closest)
      assert result == %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
    end

    test "round | :floor" do
      {:ok, result} = Timecode.with_seconds(Ratio.new(239, 240), Rates.f24(), round: :floor)
      assert result == %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
    end

    test "round | :ceil" do
      {:ok, result} = Timecode.with_seconds(Ratio.new(231, 240), Rates.f24(), round: :ceil)
      assert result == %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
    end

    test "round | :off" do
      {:ok, result} = Timecode.with_seconds(Ratio.new(239, 240), Rates.f24(), round: :off)
      assert result == %Timecode{seconds: Ratio.new(239, 240), rate: Rates.f24()}
    end

    test "ParseTimecodeError when bad format" do
      {:error, %Timecode.ParseError{} = error} =
        Timecode.with_seconds("notatimecode", Rates.f24())

      assert :unrecognized_format == error.reason
      assert "string format not recognized" = Timecode.ParseError.message(error)
    end
  end

  describe "#with_seconds!/3" do
    for test_case <- @parse_cases do
      @test_case test_case
      @test_case_negative ParseHelpers.make_negative_case(test_case)

      for input_case <- @test_case.seconds_inputs do
        @input_case input_case
        @negative_input ParseHelpers.make_negative_input(@input_case)

        test "#{@test_case.name} | #{inspect(@input_case)} | #{@test_case.rate}" do
          @input_case
          |> Timecode.with_seconds!(@test_case.rate)
          |> check_parsed!(@test_case)
        end

        test "#{@test_case.name}! | #{inspect(@input_case)} | #{@test_case.rate} | negative" do
          @negative_input
          |> Timecode.with_seconds!(@test_case_negative.rate)
          |> check_parsed!(@test_case_negative)
        end
      end
    end

    test "round | :closest | implied" do
      result = Timecode.with_seconds!(Ratio.new(239, 240), Rates.f24())
      assert result == %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
    end

    test "round | :closest | explicit" do
      result = Timecode.with_seconds!(Ratio.new(239, 240), Rates.f24(), round: :closest)
      assert result == %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
    end

    test "round | :closest | down" do
      result = Timecode.with_seconds!(Ratio.new(234, 240), Rates.f24(), round: :closest)
      assert result == %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
    end

    test "round | :floor" do
      result = Timecode.with_seconds!(Ratio.new(239, 240), Rates.f24(), round: :floor)
      assert result == %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
    end

    test "round | :ceil" do
      result = Timecode.with_seconds!(Ratio.new(231, 240), Rates.f24(), round: :ceil)
      assert result == %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
    end

    test "round | :off" do
      result = Timecode.with_seconds!(Ratio.new(239, 240), Rates.f24(), round: :off)
      assert result == %Timecode{seconds: Ratio.new(239, 240), rate: Rates.f24()}
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

  describe "#with_frames!/2" do
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

  @ppro_ticks_per_frame div(Consts.ppro_tick_per_second(), 24)

  describe "#with_seconds/3 | Premiere Ticks" do
    test "round | :closest | implied" do
      {:ok, timecode} =
        @ppro_ticks_per_frame
        |> div(2)
        |> then(&%PremiereTicks{in: &1})
        |> Timecode.with_seconds(Rates.f24())

      assert timecode == %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}
    end

    test "round | :closest | explicit" do
      {:ok, timecode} =
        @ppro_ticks_per_frame
        |> div(2)
        |> then(&%PremiereTicks{in: &1})
        |> Timecode.with_seconds(Rates.f24(), round: :closest)

      assert timecode == %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}
    end

    test "round | :closest | down" do
      {:ok, timecode} =
        @ppro_ticks_per_frame
        |> div(2)
        |> then(&(&1 - 1))
        |> then(&%PremiereTicks{in: &1})
        |> Timecode.with_seconds(Rates.f24(), round: :closest)

      assert timecode == %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}
    end

    test "round | :ceil" do
      {:ok, timecode} =
        @ppro_ticks_per_frame
        |> div(4)
        |> then(&%PremiereTicks{in: &1})
        |> Timecode.with_seconds(Rates.f24(), round: :ceil)

      assert timecode == %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}
    end

    test "round | :floor" do
      {:ok, timecode} =
        (@ppro_ticks_per_frame - 1)
        |> then(&%PremiereTicks{in: &1})
        |> Timecode.with_seconds(Rates.f24(), round: :floor)

      assert timecode == %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}
    end

    test "round | :off" do
      {:ok, timecode} =
        (Consts.ppro_tick_per_second() - 1)
        |> then(&%PremiereTicks{in: &1})
        |> Timecode.with_seconds(Rates.f24(), round: :off)

      assert timecode == %Timecode{
               seconds:
                 Ratio.new(
                   Consts.ppro_tick_per_second() - 1,
                   Consts.ppro_tick_per_second()
                 ),
               rate: Rates.f24()
             }
    end
  end

  # Checks the results of non-raising parse methods.
  @spec check_parsed(Timecode.parse_result(), map()) :: term()
  defp check_parsed(result, test_case) do
    assert {:ok, %Timecode{} = parsed} = result
    check_parsed!(parsed, test_case)
  end

  # Checks the results of raising parse methods.
  @spec check_parsed!(Timecode.t(), map()) :: term()
  defp check_parsed!(parsed, test_case) do
    assert %Timecode{} = parsed
    assert parsed.seconds == test_case.seconds
    assert parsed.rate == test_case.rate
  end

  describe "#frames/2" do
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

    test "round | :closest | implied" do
      timecode = %Timecode{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      assert Timecode.frames(timecode) == 24
    end

    test "round | :closest | explicit" do
      timecode = %Timecode{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      assert Timecode.frames(timecode, round: :closest) == 24
    end

    test "round | :closest | down" do
      timecode = %Timecode{seconds: Ratio.new(234, 240), rate: Rates.f24()}
      assert Timecode.frames(timecode) == 23
    end

    test "round | :floor" do
      timecode = %Timecode{seconds: Ratio.new(239, 240), rate: Rates.f24()}
      assert Timecode.frames(timecode, round: :floor) == 23
    end

    test "round | :ceil" do
      timecode = %Timecode{seconds: Ratio.new(231, 240), rate: Rates.f24()}
      assert Timecode.frames(timecode, round: :ceil) == 24
    end

    test "round: :off raises" do
      timecode = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      exception = assert_raise ArgumentError, fn -> Timecode.frames(timecode, round: :off) end
      assert Exception.message(exception) == "`round` cannot be `:off`"
    end
  end

  describe "#timecode/2" do
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

    test "round | :closest | implied" do
      timecode = %Timecode{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      assert Timecode.timecode(timecode) == "00:00:01:00"
    end

    test "round | :closest | explicit" do
      timecode = %Timecode{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      assert Timecode.timecode(timecode, round: :closest) == "00:00:01:00"
    end

    test "round | :closest | down" do
      timecode = %Timecode{seconds: Ratio.new(234, 240), rate: Rates.f24()}
      assert Timecode.timecode(timecode) == "00:00:00:23"
    end

    test "round | :floor" do
      timecode = %Timecode{seconds: Ratio.new(239, 240), rate: Rates.f24()}
      assert Timecode.timecode(timecode, round: :floor) == "00:00:00:23"
    end

    test "round | :ceil" do
      timecode = %Timecode{seconds: Ratio.new(231, 240), rate: Rates.f24()}
      assert Timecode.timecode(timecode, round: :ceil) == "00:00:01:00"
    end

    test "round: :off raises" do
      timecode = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      exception = assert_raise ArgumentError, fn -> Timecode.timecode(timecode, round: :off) end
      assert Exception.message(exception) == "`round` cannot be `:off`"
    end
  end

  describe "#runtime/2" do
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

      test "#{@test_case.name} | precision 9 default" do
        assert Timecode.runtime(@input_struct) == @test_case.runtime
      end

      test "#{@test_case.name} | negative" do
        assert Timecode.runtime(@input_struct_negative, 9) == @test_case_negative.runtime
      end
    end
  end

  describe "#premiere_ticks/2" do
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

    @one_quarter_tick Ratio.new(1, Consts.ppro_tick_per_second() * 4)
    @one_half_tick Ratio.new(1, Consts.ppro_tick_per_second() * 2)
    @three_quarter_tick Ratio.add(@one_half_tick, @one_quarter_tick)

    test "round | :closest | implied" do
      timecode = %Timecode{
        seconds: 1 |> Ratio.new() |> Ratio.add(@one_half_tick),
        rate: Rates.f24()
      }

      assert Timecode.premiere_ticks(timecode) == Consts.ppro_tick_per_second() + 1
    end

    test "round | :closest | explicit" do
      timecode = %Timecode{
        seconds: 1 |> Ratio.new() |> Ratio.add(@one_half_tick),
        rate: Rates.f24()
      }

      expexted = Consts.ppro_tick_per_second() + 1
      assert Timecode.premiere_ticks(timecode, round: :closest) == expexted
    end

    test "round | :closest | down" do
      timecode = %Timecode{
        seconds: 1 |> Ratio.new() |> Ratio.add(@one_quarter_tick),
        rate: Rates.f24()
      }

      assert Timecode.premiere_ticks(timecode, round: :closest) == Consts.ppro_tick_per_second()
    end

    test "round | :floor" do
      timecode = %Timecode{
        seconds: 1 |> Ratio.new() |> Ratio.add(@three_quarter_tick),
        rate: Rates.f24()
      }

      assert Timecode.premiere_ticks(timecode, round: :floor) == Consts.ppro_tick_per_second()
    end

    test "round | :ceil" do
      timecode = %Timecode{
        seconds: 1 |> Ratio.new() |> Ratio.add(@one_quarter_tick),
        rate: Rates.f24()
      }

      expected = Consts.ppro_tick_per_second() + 1
      assert Timecode.premiere_ticks(timecode, round: :ceil) == expected
    end

    test "round: :off raises" do
      timecode = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      exception =
        assert_raise ArgumentError, fn -> Timecode.premiere_ticks(timecode, round: :off) end

      assert Exception.message(exception) == "`round` cannot be `:off`"
    end
  end

  describe "#feet_and_frames/2" do
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

    test "round | :closest | implied" do
      timecode = %Timecode{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      assert Timecode.feet_and_frames(timecode) == "1+08"
    end

    test "round | :closest | explicit" do
      timecode = %Timecode{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      assert Timecode.feet_and_frames(timecode, round: :closest) == "1+08"
    end

    test "round | :closest | down" do
      timecode = %Timecode{seconds: Ratio.new(234, 240), rate: Rates.f24()}
      assert Timecode.feet_and_frames(timecode) == "1+07"
    end

    test "round | :floor" do
      timecode = %Timecode{seconds: Ratio.new(239, 240), rate: Rates.f24()}
      assert Timecode.feet_and_frames(timecode, round: :floor) == "1+07"
    end

    test "round | :ceil" do
      timecode = %Timecode{seconds: Ratio.new(231, 240), rate: Rates.f24()}
      assert Timecode.feet_and_frames(timecode, round: :ceil) == "1+08"
    end

    test "round: :off raises" do
      timecode = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      exception =
        assert_raise ArgumentError, fn -> Timecode.feet_and_frames(timecode, round: :off) end

      assert Exception.message(exception) == "`round` cannot be `:off`"
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

  describe "#with_seconds/3 - partial runtime" do
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

  describe "#rebase/2" do
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
  end

  describe "#rebase!/2" do
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
  end

  describe "#add/2" do
    @add_cases [
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        expected: Timecode.with_frames!("02:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("00:00:00:00", Rates.f23_98()),
        expected: Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("-01:00:00:00", Rates.f23_98()),
        expected: Timecode.with_frames!("00:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("-02:00:00:00", Rates.f23_98()),
        expected: Timecode.with_frames!("-01:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("10:12:13:14", Rates.f23_98()),
        b: Timecode.with_frames!("14:13:12:11", Rates.f23_98()),
        expected: Timecode.with_frames!("24:25:26:01", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f47_95()),
        expected: Timecode.with_frames!("02:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("00:00:00:02", Rates.f47_95()),
        expected: Timecode.with_frames!("01:00:00:01", Rates.f23_98())
      }
    ]

    for add_case <- @add_cases do
      @add_case add_case

      test "#{add_case.a} + #{add_case.b} == #{add_case.expected}" do
        assert Timecode.add(@add_case.a, @add_case.b) == @add_case.expected
      end

      if add_case.a.rate == add_case.b.rate do
        test "#{add_case.a} + #{add_case.b} == #{add_case.expected} | integer b" do
          assert Timecode.add(@add_case.a, Timecode.frames(@add_case.b)) == @add_case.expected
        end

        test "#{add_case.a} + #{add_case.b} == #{add_case.expected} | string b" do
          assert Timecode.add(@add_case.a, Timecode.timecode(@add_case.b)) == @add_case.expected
        end
      end
    end

    test "round | :closest | implied" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.add(a, b) == expected
    end

    test "round | :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.add(a, b, round: :closest) == expected
    end

    test "round | :closest | down" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(4, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.add(a, b, round: :closest) == expected
    end

    test "round | :floor" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(9, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.add(a, b, round: :floor) == expected
    end

    test "round | :ceil" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(1, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.add(a, b, round: :ceil) == expected
    end

    test "round | :off" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(235, 240), rate: Rates.f24()}

      assert Timecode.add(a, b, round: :off) == expected
    end
  end

  describe "#sub/2" do
    @sub_cases [
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        expected: Timecode.with_frames!("00:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("00:00:00:00", Rates.f23_98()),
        expected: Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("-01:00:00:00", Rates.f23_98()),
        expected: Timecode.with_frames!("02:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("02:00:00:00", Rates.f23_98()),
        expected: Timecode.with_frames!("-01:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("34:10:09:08", Rates.f23_98()),
        b: Timecode.with_frames!("10:06:07:14", Rates.f23_98()),
        expected: Timecode.with_frames!("24:04:01:18", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("02:00:00:00", Rates.f23_98()),
        b: Timecode.with_frames!("01:00:00:00", Rates.f47_95()),
        expected: Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:02", Rates.f23_98()),
        b: Timecode.with_frames!("00:00:00:02", Rates.f47_95()),
        expected: Timecode.with_frames!("01:00:00:01", Rates.f23_98())
      }
    ]

    for sub_case <- @sub_cases do
      @sub_case sub_case

      test "#{sub_case.a} - #{sub_case.b} == #{sub_case.expected}" do
        assert Timecode.sub(@sub_case.a, @sub_case.b) == @sub_case.expected
      end

      if sub_case.a.rate == sub_case.b.rate do
        test "#{sub_case.a} - #{sub_case.b} == #{sub_case.expected} | integer b" do
          assert Timecode.sub(@sub_case.a, Timecode.frames(@sub_case.b)) == @sub_case.expected
        end

        test "#{sub_case.a} - #{sub_case.b} == #{sub_case.expected} | string b" do
          assert Timecode.sub(@sub_case.a, Timecode.timecode(@sub_case.b)) == @sub_case.expected
        end
      end
    end

    test "round | :closest | implied" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.sub(a, b) == expected
    end

    test "round | :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.sub(a, b, round: :closest) == expected
    end

    test "round | :closest | down" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(6, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.sub(a, b, round: :closest) == expected
    end

    test "round | :floor" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(1, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.sub(a, b, round: :floor) == expected
    end

    test "round | :ceil" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(9, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.sub(a, b, round: :ceil) == expected
    end

    test "round | :off" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(235, 240), rate: Rates.f24()}

      assert Timecode.sub(a, b, round: :off) == expected
    end
  end

  describe "#mult/2" do
    @mult_cases [
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: 2,
        expected: Timecode.with_frames!("02:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: 0.5,
        expected: Timecode.with_frames!("00:30:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Ratio.new(1, 2),
        expected: Timecode.with_frames!("00:30:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: 1,
        expected: Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: 0,
        expected: Timecode.with_frames!("00:00:00:00", Rates.f23_98())
      }
    ]

    for mult_case <- @mult_cases do
      @mult_case mult_case

      test "#{mult_case.a} * #{inspect(mult_case.b)} == #{mult_case.expected}" do
        assert Timecode.mult(@mult_case.a, @mult_case.b) == @mult_case.expected
      end
    end

    test "round | :closest | implied" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(235, 240)
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.mult(a, b) == expected
    end

    test "round | :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(235, 240)
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.mult(a, b, round: :closest) == expected
    end

    test "round | :closest | down" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(234, 240)
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.mult(a, b, round: :closest) == expected
    end

    test "round | :floor" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(239, 240)
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.mult(a, b, round: :floor) == expected
    end

    test "round | :ceil" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(231, 240)
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.mult(a, b, round: :ceil) == expected
    end

    test "round | :off" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(239, 240)
      expected = %Timecode{seconds: Ratio.new(239, 240), rate: Rates.f24()}

      assert Timecode.mult(a, b, round: :off) == expected
    end
  end

  describe "#div/2" do
    @div_cases [
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: 2,
        expected: Timecode.with_frames!("00:30:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: 0.5,
        expected: Timecode.with_frames!("02:00:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Ratio.new(3, 2),
        expected: Timecode.with_frames!("00:40:00:00", Rates.f23_98())
      },
      %{
        a: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
        b: 1,
        expected: Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      }
    ]

    for div_case <- @div_cases do
      @div_case div_case

      test "#{div_case.a} * #{inspect(div_case.b)} == #{div_case.expected}" do
        assert Timecode.div(@div_case.a, @div_case.b) == @div_case.expected
      end
    end

    test "round | :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 48
      expected = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.div(a, b, round: :closest) == expected
    end

    test "round | :closest | down" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 48 * 2
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.div(a, b, round: :closest) == expected
    end

    test "round | :floor" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 36
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.div(a, b, round: :floor) == expected
    end

    test "round | :floor | :implied" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 36
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.div(a, b) == expected
    end

    test "round | :ceil" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 48 * 2
      expected = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.div(a, b, round: :ceil) == expected
    end

    test "round | :off" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 48
      expected = %Timecode{seconds: Ratio.new(1, 48), rate: Rates.f24()}

      assert Timecode.div(a, b, round: :off) == expected
    end
  end

  @divrem_cases [
    %{
      dividend: Timecode.with_frames!("01:00:00:00", Rates.f24()),
      divisor: 2,
      expected_quotient: Timecode.with_frames!("00:30:00:00", Rates.f24()),
      expected_remainder: Timecode.with_frames!("00:00:00:00", Rates.f24())
    },
    %{
      dividend: Timecode.with_frames!("-01:00:00:00", Rates.f24()),
      divisor: 2,
      expected_quotient: Timecode.with_frames!("-00:30:00:00", Rates.f24()),
      expected_remainder: Timecode.with_frames!("00:00:00:00", Rates.f24())
    },
    %{
      dividend: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
      divisor: 2,
      expected_quotient: Timecode.with_frames!("00:30:00:00", Rates.f23_98()),
      expected_remainder: Timecode.with_frames!("00:00:00:00", Rates.f23_98())
    },
    %{
      dividend: Timecode.with_frames!("01:00:00:01", Rates.f24()),
      divisor: 2,
      expected_quotient: Timecode.with_frames!("00:30:00:00", Rates.f24()),
      expected_remainder: Timecode.with_frames!("00:00:00:01", Rates.f24())
    },
    %{
      dividend: Timecode.with_frames!("-01:00:00:01", Rates.f24()),
      divisor: 2,
      expected_quotient: Timecode.with_frames!("-00:30:00:00", Rates.f24()),
      expected_remainder: Timecode.with_frames!("00:00:00:01", Rates.f24())
    },
    %{
      dividend: Timecode.with_frames!("-01:00:00:01", Rates.f24()),
      divisor: -2,
      expected_quotient: Timecode.with_frames!("00:30:00:01", Rates.f24()),
      expected_remainder: Timecode.with_frames!("-00:00:00:01", Rates.f24())
    },
    %{
      dividend: Timecode.with_frames!("01:00:00:01", Rates.f23_98()),
      divisor: 2,
      expected_quotient: Timecode.with_frames!("00:30:00:00", Rates.f23_98()),
      expected_remainder: Timecode.with_frames!("00:00:00:01", Rates.f23_98())
    },
    %{
      dividend: Timecode.with_frames!("01:00:00:01", Rates.f24()),
      divisor: 4,
      expected_quotient: Timecode.with_frames!("00:15:00:00", Rates.f24()),
      expected_remainder: Timecode.with_frames!("00:00:00:01", Rates.f24())
    },
    %{
      dividend: Timecode.with_frames!("01:00:00:01", Rates.f23_98()),
      divisor: 4,
      expected_quotient: Timecode.with_frames!("00:15:00:00", Rates.f23_98()),
      expected_remainder: Timecode.with_frames!("00:00:00:01", Rates.f23_98())
    },
    %{
      dividend: Timecode.with_frames!("01:00:00:02", Rates.f23_98()),
      divisor: 4,
      expected_quotient: Timecode.with_frames!("00:15:00:00", Rates.f23_98()),
      expected_remainder: Timecode.with_frames!("00:00:00:02", Rates.f23_98())
    },
    %{
      dividend: Timecode.with_frames!("01:00:00:01", Rates.f24()),
      divisor: 1.5,
      expected_quotient: Timecode.with_frames!("00:40:00:00", Rates.f24()),
      expected_remainder: Timecode.with_frames!("00:00:00:01", Rates.f24())
    },
    %{
      dividend: Timecode.with_frames!("01:00:00:01", Rates.f23_98()),
      divisor: 1.5,
      expected_quotient: Timecode.with_frames!("00:40:00:00", Rates.f23_98()),
      expected_remainder: Timecode.with_frames!("00:00:00:01", Rates.f23_98())
    }
  ]

  describe "#divrem/2" do
    for divrem_case <- @divrem_cases do
      @divrem_case divrem_case

      test_name =
        "#{divrem_case.dividend} /% #{divrem_case.divisor}" <>
          " == {#{divrem_case.expected_quotient}, #{divrem_case.expected_remainder}}"

      test test_name do
        %{
          dividend: dividend,
          divisor: divisor,
          expected_quotient: expected_quotient,
          expected_remainder: expected_remainder
        } = @divrem_case

        result = Timecode.divrem(dividend, divisor)
        assert result == {expected_quotient, expected_remainder}
      end
    end

    test "round | frames :closest | implicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected_q = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.divrem(a, b) == {expected_q, expected_r}
    end

    test "round | frames :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected_q = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_frames: :closest) == {expected_q, expected_r}
    end

    test "round | frames :floor" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected_q = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_frames: :floor) == {expected_q, expected_r}
    end

    test "round | frames :ceil" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected_q = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_frames: :ceil) == {expected_q, expected_r}
    end

    test "round | rem :closest | implicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected_q = %Timecode{seconds: Ratio.new(14, 24), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.divrem(a, b) == {expected_q, expected_r}
    end

    test "round | rem :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected_q = %Timecode{seconds: Ratio.new(14, 24), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_remainder: :closest) == {expected_q, expected_r}
    end

    test "round | rem :ceil" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected_q = %Timecode{seconds: Ratio.new(14, 24), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_remainder: :ceil) == {expected_q, expected_r}
    end

    test "round | rem :floor" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected_q = %Timecode{seconds: Ratio.new(14, 24), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(0, 24), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_remainder: :floor) == {expected_q, expected_r}
    end

    test "round | frames :off | raises" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Timecode.divrem(a, b, round_frames: :off) end
      assert Exception.message(exception) == "`round_frames` cannot be `:off`"
    end

    test "round | remainder :off | raises" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception =
        assert_raise ArgumentError, fn -> Timecode.divrem(a, b, round_remainder: :off) end

      assert Exception.message(exception) == "`round_remainder` cannot be `:off`"
    end
  end

  describe "#rem/2" do
    for rem_case <- @divrem_cases do
      @rem_case rem_case

      test "#{rem_case.dividend} % #{rem_case.divisor} == #{rem_case.expected_remainder}" do
        %{
          dividend: dividend,
          divisor: divisor,
          expected_remainder: expected
        } = @rem_case

        assert Timecode.rem(dividend, divisor) == expected
      end
    end

    test "round | frames :closest | implicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.rem(a, b) == expected
    end

    test "round | frames :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_frames: :closest) == expected
    end

    test "round | frames :floor" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_frames: :floor) == expected
    end

    test "round | frames :ceil" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_frames: :ceil) == expected
    end

    test "round | rem :closest | implicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.rem(a, b) == expected
    end

    test "round | rem :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_remainder: :closest) == expected
    end

    test "round | rem :ceil" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_remainder: :ceil) == expected
    end

    test "round | rem :floor" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected = %Timecode{seconds: Ratio.new(0, 24), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_remainder: :floor) == expected
    end

    test "round | frames :off | raises" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Timecode.rem(a, b, round_frames: :off) end
      assert Exception.message(exception) == "`round_frames` cannot be `:off`"
    end

    test "round | remainder :off | raises" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Timecode.rem(a, b, round_remainder: :off) end

      assert Exception.message(exception) == "`round_remainder` cannot be `:off`"
    end
  end

  describe "#negate/1" do
    @negate_cases [
      %{
        input: %Timecode{seconds: Ratio.new(1), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(-1), rate: Rates.f23_98()}
      },
      %{
        input: %Timecode{seconds: Ratio.new(-1), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(1), rate: Rates.f23_98()}
      },
      %{
        input: %Timecode{seconds: Ratio.new(0), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(0), rate: Rates.f23_98()}
      }
    ]

    for negate_case <- @negate_cases do
      @negate_case negate_case

      test "#{negate_case.input} negated == #{negate_case.expected}" do
        %{
          input: input,
          expected: expected
        } = @negate_case

        assert Timecode.minus(input) == expected
      end
    end
  end

  describe "#abs/1" do
    @abs_cases [
      %{
        input: %Timecode{seconds: Ratio.new(1), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(1), rate: Rates.f23_98()}
      },
      %{
        input: %Timecode{seconds: Ratio.new(-1), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(1), rate: Rates.f23_98()}
      },
      %{
        input: %Timecode{seconds: Ratio.new(0), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(0), rate: Rates.f23_98()}
      }
    ]

    for abs_case <- @abs_cases do
      @abs_case abs_case

      test "#{abs_case.input} negated == #{abs_case.expected}" do
        %{
          input: input,
          expected: expected
        } = @abs_case

        assert Timecode.abs(input) == expected
      end
    end
  end

  describe "String.Chars.to_string/1" do
    test "renders expected for non-drop" do
      tc = Timecode.with_frames!(24, Rates.f23_98())
      assert String.Chars.to_string(tc) == "<00:00:01:00 <23.98 NTSC>>"
    end

    test "renders with `;` frames sep for drop-frame" do
      tc = Timecode.with_frames!(30, Rates.f29_97_df())
      assert String.Chars.to_string(tc) == "<00:00:01;00 <29.97 NTSC DF>>"
    end
  end

  describe "Inspect.inspect/2" do
    test "renders expected for non-drop" do
      tc = Timecode.with_frames!(24, Rates.f23_98())
      assert Inspect.inspect(tc, Inspect.Opts.new([])) == "<00:00:01:00 <23.98 NTSC>>"
    end

    test "renders with `;` frames sep for drop-frame" do
      tc = Timecode.with_frames!(30, Rates.f29_97_df())
      assert Inspect.inspect(tc, Inspect.Opts.new([])) == "<00:00:01;00 <29.97 NTSC DF>>"
    end
  end
end
