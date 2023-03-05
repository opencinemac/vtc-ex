defmodule Vtc.FramerateTest.ParseCase do
  @moduledoc false

  defstruct [:name, :inputs, :ntsc, :playback, :timebase, :err, err_msg: ""]

  alias Vtc.Framerate
  alias Vtc.Ntsc

  @type t :: %__MODULE__{
          name: String.t(),
          inputs: list(Ratio.t() | integer | float | bitstring),
          ntsc: Ntsc.t(),
          playback: Ratio.t(),
          timebase: Ratio.t(),
          err: Framerate.ParseError | nil,
          err_msg: String.t()
        }
end

defmodule Vtc.FramerateTest.ConstCase do
  @moduledoc false

  defstruct [:const, :ntsc, :playback, :timebase]

  @type t :: %__MODULE__{
          const: Vtc.Framerate.t(),
          ntsc: Vtc.Ntsc.t(),
          playback: Ratio.t(),
          timebase: Ratio.t()
        }
end

defmodule Vtc.FramerateTest do
  @moduledoc false

  use ExUnit.Case
  use Ratio

  alias Vtc.Rates

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
        ntsc: :NonDrop,
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
        ntsc: :Drop,
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
        ntsc: :Drop,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %ParseCase{
        name: "24 fps",
        inputs: [
          Ratio.new(24, 1),
          24,
          "24/1",
          "1/24"
        ],
        ntsc: :None,
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
        ntsc: :Drop,
        err: %Vtc.Framerate.ParseError{reason: :bad_drop_rate},
        err_msg: "drop-frame rates must be divisible by 30000/1001"
      },
      %ParseCase{
        name: "error - uknown format",
        inputs: [
          "notarate"
        ],
        ntsc: :Drop,
        err: %Vtc.Framerate.ParseError{reason: :unrecognized_format},
        err_msg: "framerate string format not recognized"
      },
      %ParseCase{
        name: "error - unknown format",
        inputs: [
          24
        ],
        ntsc: :NotAnNtsc,
        err: %Vtc.Framerate.ParseError{reason: :invalid_ntsc},
        err_msg: "ntsc is not a valid atom. must be :NonDrop, :Drop, or None"
      },
      %ParseCase{
        name: "error - imprecise",
        inputs: [
          23.98,
          "23.98"
        ],
        ntsc: :None,
        err: %Vtc.Framerate.ParseError{reason: :imprecise},
        err_msg: "floats are not precise enough to create a non-NTSC Framerate"
      }
    ]

    for tc <- cases do
      case_name = tc.name
      @test_case tc
      for {input_case, i} <- Enum.with_index(tc.inputs) do
        @input input_case
        test "#{case_name} - #{i}: #{input_case} - new" do
          case Vtc.Framerate.new(@input, @test_case.ntsc) do
            {:ok, rate} ->
              check_parsed(@test_case, rate)

            {:error, err} ->
              # We have to do this here, or the compiler complains the expected error
              # could be nil
              expected =
                if is_nil(@test_case.err) do
                  raise "error not supplied for test case"
                else
                  @test_case.err
                end

              assert expected.reason == err.reason
              assert @test_case.err_msg == Vtc.Framerate.ParseError.message(err)
          end
        end

        test "#{case_name} - #{i}: #{input_case} - new!" do
          if @test_case.err == nil do
            rate = Vtc.Framerate.new!(@input, @test_case.ntsc)
            check_parsed(@test_case, rate)
          else
            assert_raise Vtc.Framerate.ParseError,
                         fn ->
                           Vtc.Framerate.new!(@input, @test_case.ntsc)
                         end
          end
        end
      end
    end

    @spec check_parsed(ParseCase.t(), Vtc.Framerate.t()) :: nil
    defp check_parsed(case, parsed) do
      assert case.playback == parsed.playback
      assert case.timebase == Vtc.Framerate.timebase(parsed)
      assert case.ntsc == parsed.ntsc
    end
  end

  describe "#consts" do
    use ExUnit.Case
    use Ratio

    alias Vtc.Rates

    cases = [
      %ConstCase{
        const: Rates.f23_98(),
        ntsc: :NonDrop,
        playback: Ratio.new(24_000, 1001),
        timebase: Ratio.new(24, 1)
      },
      %ConstCase{
        const: Rates.f24(),
        ntsc: :None,
        playback: Ratio.new(24, 1),
        timebase: Ratio.new(24, 1)
      },
      %ConstCase{
        const: Rates.f29_97_ndf(),
        ntsc: :NonDrop,
        playback: Ratio.new(30_000, 1001),
        timebase: Ratio.new(30, 1)
      },
      %ConstCase{
        const: Rates.f29_97_df(),
        ntsc: :Drop,
        playback: Ratio.new(30_000, 1001),
        timebase: Ratio.new(30, 1)
      },
      %ConstCase{
        const: Rates.f30(),
        ntsc: :None,
        playback: Ratio.new(30, 1),
        timebase: Ratio.new(30, 1)
      },
      %ConstCase{
        const: Rates.f47_95(),
        ntsc: :NonDrop,
        playback: Ratio.new(48_000, 1001),
        timebase: Ratio.new(48, 1)
      },
      %ConstCase{
        const: Rates.f48(),
        ntsc: :None,
        playback: Ratio.new(48, 1),
        timebase: Ratio.new(48, 1)
      },
      %ConstCase{
        const: Rates.f59_94_ndf(),
        ntsc: :NonDrop,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %ConstCase{
        const: Rates.f59_94_df(),
        ntsc: :Drop,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %ConstCase{
        const: Rates.f60(),
        ntsc: :None,
        playback: Ratio.new(60, 1),
        timebase: Ratio.new(60, 1)
      }
    ]

    for tc <- cases do
      const = tc.const
      @test_case tc

      test "#{const} const" do
        assert @test_case.ntsc == @test_case.const.ntsc
        assert @test_case.playback == @test_case.const.playback
        assert @test_case.timebase == Vtc.Framerate.timebase(@test_case.const)
      end
    end
  end
end
