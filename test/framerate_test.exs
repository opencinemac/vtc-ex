defmodule Vtc.FramerateTest.ParseCase do
  @moduledoc false

  defstruct [:name, :inputs, :ntsc, :playback, :timebase, :err, err_msg: ""]

  alias Vtc.Framerate

  @type t :: %__MODULE__{
          name: String.t(),
          inputs: [Ratio.t() | integer() | float() | String.t()],
          ntsc: Framerate.ntsc(),
          playback: Ratio.t(),
          timebase: Ratio.t(),
          err: Framerate.ParseError | nil,
          err_msg: String.t()
        }
end

defmodule Vtc.FramerateTest.ConstCase do
  @moduledoc false

  alias Vtc.Framerate
  alias Vtc.Utils.Framerate

  defstruct [:const, :ntsc, :playback, :timebase]

  @type t :: %__MODULE__{
          const: Framerate.t(),
          ntsc: Framerate.ntsc(),
          playback: Ratio.t(),
          timebase: Ratio.t()
        }
end

defmodule Vtc.FramerateTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Vtc.Rates

  alias Vtc.Framerate
  alias Vtc.FramerateTest.ConstCase
  alias Vtc.FramerateTest.ParseCase

  describe "#parse" do
    cases = [
      %ParseCase{
        name: "23.98 NTSC",
        inputs: [
          Ratio.new(24, 1),
          Ratio.new(24_000, 1001),
          24,
          24.0,
          23.98,
          23.976,
          "24",
          "24.0",
          "23.98",
          "23.976",
          "24/1",
          "24000/1001",
          "1/24",
          "1001/24000"
        ],
        ntsc: :non_drop,
        playback: Ratio.new(24_000, 1001),
        timebase: Ratio.new(24, 1)
      },
      %ParseCase{
        name: "29.97 NTSC DF",
        inputs: [
          Ratio.new(30, 1),
          Ratio.new(30_000, 1001),
          30,
          30.0,
          29.97,
          "30",
          "30.0",
          "29.97",
          "30/1",
          "30000/1001",
          "1/30",
          "1001/30000"
        ],
        ntsc: :drop,
        playback: Ratio.new(30_000, 1001),
        timebase: Ratio.new(30, 1)
      },
      %ParseCase{
        name: "59.94 NTSC DF",
        inputs: [
          Ratio.new(60, 1),
          Ratio.new(60_000, 1001),
          60,
          60.0,
          59.94,
          "60",
          "60.0",
          "59.94",
          "60/1",
          "60000/1001",
          "1/60",
          "1001/60000"
        ],
        ntsc: :drop,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %ParseCase{
        name: "24 fps",
        inputs: [
          Ratio.new(24, 1),
          24,
          24.0,
          "24/1",
          "1/24",
          "24.0"
        ],
        ntsc: nil,
        playback: Ratio.new(24, 1),
        timebase: Ratio.new(24, 1)
      },
      %ParseCase{
        name: "error - bad drop",
        inputs: [
          Ratio.new(24, 1),
          24,
          "24/1",
          "1/24",
          "29"
        ],
        ntsc: :drop,
        err: %Framerate.ParseError{reason: :bad_drop_rate},
        err_msg: "drop-frame rates must be divisible by 30000/1001"
      },
      %ParseCase{
        name: "error - uknown format",
        inputs: [
          "notarate"
        ],
        ntsc: :drop,
        err: %Framerate.ParseError{reason: :unrecognized_format},
        err_msg: "framerate string format not recognized"
      },
      %ParseCase{
        name: "error - unknown format",
        inputs: [
          24
        ],
        ntsc: :NotAnNtsc,
        err: %Framerate.ParseError{reason: :invalid_ntsc},
        err_msg: "ntsc is not a valid atom. must be :non_drop, :drop, or nil"
      },
      %ParseCase{
        name: "error - imprecise",
        inputs: [
          23.98,
          "23.98"
        ],
        ntsc: nil,
        err: %Framerate.ParseError{reason: :imprecise},
        err_msg: "non-whole floats are not precise enough to create a non-NTSC Framerate"
      }
    ]

    for this_case <- cases do
      case_name = this_case.name
      @test_case this_case

      for {input_case, i} <- Enum.with_index(this_case.inputs) do
        @input input_case

        test "#{case_name} - #{i}: #{inspect(input_case)} - new" do
          case Framerate.new(@input, @test_case.ntsc) do
            {:ok, rate} ->
              check_parsed(@test_case, rate)

            {:error, err} ->
              expected_reason = Map.get(@test_case.err, :reason, "no error expected")
              assert expected_reason == err.reason
              assert @test_case.err_msg == Framerate.ParseError.message(err)
          end
        end

        test "#{case_name} - #{i}: #{inspect(input_case)} - new!" do
          if @test_case.err == nil do
            rate = Framerate.new!(@input, @test_case.ntsc)
            check_parsed(@test_case, rate)
          else
            function = fn -> Framerate.new!(@input, @test_case.ntsc) end
            assert_raise Framerate.ParseError, function
          end
        end
      end
    end

    @spec check_parsed(ParseCase.t(), Framerate.t()) :: nil
    defp check_parsed(test_case, parsed) do
      assert test_case.playback == parsed.playback
      assert test_case.timebase == Framerate.timebase(parsed)
      assert test_case.ntsc == parsed.ntsc
    end
  end

  describe "#consts" do
    use ExUnit.Case, async: true

    alias Vtc.Rates

    cases = [
      %ConstCase{
        const: Rates.f23_98(),
        ntsc: :non_drop,
        playback: Ratio.new(24_000, 1001),
        timebase: Ratio.new(24, 1)
      },
      %ConstCase{
        const: Rates.f24(),
        ntsc: nil,
        playback: Ratio.new(24, 1),
        timebase: Ratio.new(24, 1)
      },
      %ConstCase{
        const: Rates.f29_97_ndf(),
        ntsc: :non_drop,
        playback: Ratio.new(30_000, 1001),
        timebase: Ratio.new(30, 1)
      },
      %ConstCase{
        const: Rates.f29_97_df(),
        ntsc: :drop,
        playback: Ratio.new(30_000, 1001),
        timebase: Ratio.new(30, 1)
      },
      %ConstCase{
        const: Rates.f30(),
        ntsc: nil,
        playback: Ratio.new(30, 1),
        timebase: Ratio.new(30, 1)
      },
      %ConstCase{
        const: Rates.f47_95(),
        ntsc: :non_drop,
        playback: Ratio.new(48_000, 1001),
        timebase: Ratio.new(48, 1)
      },
      %ConstCase{
        const: Rates.f48(),
        ntsc: nil,
        playback: Ratio.new(48, 1),
        timebase: Ratio.new(48, 1)
      },
      %ConstCase{
        const: Rates.f59_94_ndf(),
        ntsc: :non_drop,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %ConstCase{
        const: Rates.f59_94_df(),
        ntsc: :drop,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %ConstCase{
        const: Rates.f60(),
        ntsc: nil,
        playback: Ratio.new(60, 1),
        timebase: Ratio.new(60, 1)
      }
    ]

    for this_case <- cases do
      const = this_case.const
      @test_case this_case

      test "#{const} const" do
        assert @test_case.ntsc == @test_case.const.ntsc
        assert @test_case.playback == @test_case.const.playback
        assert @test_case.timebase == Framerate.timebase(@test_case.const)
      end
    end
  end

  describe "#String.Chars.to_string/1" do
    test "tags `NDF` for valid drop_frame rates" do
      assert String.Chars.to_string(Rates.f29_97_ndf()) == "<29.97 NTSC NDF>"
    end

    test "tags `DF` for drop_frame" do
      assert String.Chars.to_string(Rates.f29_97_df()) == "<29.97 NTSC DF>"
    end

    test "doesnt tag non-valid drop_frame rates" do
      assert String.Chars.to_string(Rates.f23_98()) == "<23.98 NTSC>"
    end

    test "tags `fps` when not NTSC" do
      assert String.Chars.to_string(Rates.f24()) == "<24.0 fps>"
    end
  end

  describe "#Inspect.inspect/1" do
    test "tags `NDF` for valid drop_frame rates" do
      assert Inspect.inspect(Rates.f29_97_ndf(), Inspect.Opts.new([])) ==
               "<29.97 NTSC NDF>"
    end

    test "tags `DF` for drop_frame" do
      assert Inspect.inspect(Rates.f29_97_df(), Inspect.Opts.new([])) == "<29.97 NTSC DF>"
    end

    test "doesnt tag non-valid drop_frame rates" do
      assert Inspect.inspect(Rates.f23_98(), Inspect.Opts.new([])) == "<23.98 NTSC>"
    end

    test "tags `fps` when not NTSC" do
      assert Inspect.inspect(Rates.f24(), Inspect.Opts.new([])) == "<24.0 fps>"
    end
  end
end
