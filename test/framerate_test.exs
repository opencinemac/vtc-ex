defmodule ParseCase do
  defstruct [:name, :inputs, :ntsc, :playback, :timebase, :err, err_msg: ""]

  @type t :: %ParseCase{
          name: bitstring,
          inputs: list(Ratio.t() | integer | float | bitstring),
          ntsc: Vtc.Ntsc.t(),
          playback: Ratio.t(),
          timebase: Ratio.t(),
          err: Vtc.Framerate.ParseError | nil,
          err_msg: String.t()
        }
end

defmodule FramerateParseTest do
  use ExUnit.Case
  use Ratio

  cases = [
    %ParseCase{
      name: "23.98 NTSC",
      inputs: [
        Ratio.new(24, 1),
        Ratio.new(24000, 1001),
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
      playback: Ratio.new(24000, 1001),
      timebase: Ratio.new(24, 1)
    },
    %ParseCase{
      name: "29.97 NTSC DF",
      inputs: [
        Ratio.new(30, 1),
        Ratio.new(30000, 1001),
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
      playback: Ratio.new(30000, 1001),
      timebase: Ratio.new(30, 1)
    },
    %ParseCase{
      name: "59.94 NTSC DF",
      inputs: [
        Ratio.new(60, 1),
        Ratio.new(60000, 1001),
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
      playback: Ratio.new(60000, 1001),
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

  @spec check_parsed(ParseCase.t(), Vtc.Framerate.t()) :: nil
  def check_parsed(case, parsed) do
    assert case.playback == parsed.playback
    assert case.timebase == Vtc.Framerate.timebase(parsed)
    assert case.ntsc == parsed.ntsc
  end

  for tc <- cases do
    caseName = tc.name
    @testCase tc
    for {inputCase, i} <- Enum.with_index(tc.inputs) do
      @input inputCase
      test "#{caseName} - #{i}: #{inputCase} - new" do
        case Vtc.Framerate.new(@input, @testCase.ntsc) do
          {:ok, rate} ->
            check_parsed(@testCase, rate)

          {:error, err} ->
            # We have to do this here, or the compiler complains the expected error
            # could be nil
            expected =
              if is_nil(@testCase.err) do
                raise "error not supplied for test case"
              else
                @testCase.err
              end

            assert expected.reason == err.reason
            assert @testCase.err_msg == Vtc.Framerate.ParseError.message(err)
        end
      end

      test "#{caseName} - #{i}: #{inputCase} - new!" do
        if @testCase.err == nil do
          rate = Vtc.Framerate.new!(@input, @testCase.ntsc)
          check_parsed(@testCase, rate)
        else
          assert_raise Vtc.Framerate.ParseError,
                       fn ->
                         Vtc.Framerate.new!(@input, @testCase.ntsc)
                       end
        end
      end
    end
  end
end

defmodule ConstCase do
  defstruct [:const, :ntsc, :playback, :timebase]

  @type t :: %ConstCase{
          const: Vtc.Framerate.t(),
          ntsc: Vtc.Ntsc.t(),
          playback: Ratio.t(),
          timebase: Ratio.t()
        }
end

defmodule TestFramerateConsts do
  defmodule RuntimePartialTest do
    use ExUnit.Case
    use Ratio

    cases = [
      %ConstCase{
        const: Vtc.Rate.f23_98(),
        ntsc: :NonDrop,
        playback: Ratio.new(24000, 1001),
        timebase: Ratio.new(24, 1)
      },
      %ConstCase{
        const: Vtc.Rate.f24(),
        ntsc: :None,
        playback: Ratio.new(24, 1),
        timebase: Ratio.new(24, 1)
      },
      %ConstCase{
        const: Vtc.Rate.f29_97_Ndf(),
        ntsc: :NonDrop,
        playback: Ratio.new(30000, 1001),
        timebase: Ratio.new(30, 1)
      },
      %ConstCase{
        const: Vtc.Rate.f29_97_Df(),
        ntsc: :Drop,
        playback: Ratio.new(30000, 1001),
        timebase: Ratio.new(30, 1)
      },
      %ConstCase{
        const: Vtc.Rate.f30(),
        ntsc: :None,
        playback: Ratio.new(30, 1),
        timebase: Ratio.new(30, 1)
      },
      %ConstCase{
        const: Vtc.Rate.f47_95(),
        ntsc: :NonDrop,
        playback: Ratio.new(48000, 1001),
        timebase: Ratio.new(48, 1)
      },
      %ConstCase{
        const: Vtc.Rate.f48(),
        ntsc: :None,
        playback: Ratio.new(48, 1),
        timebase: Ratio.new(48, 1)
      },
      %ConstCase{
        const: Vtc.Rate.f59_94_Ndf(),
        ntsc: :NonDrop,
        playback: Ratio.new(60000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %ConstCase{
        const: Vtc.Rate.f59_94_Df(),
        ntsc: :Drop,
        playback: Ratio.new(60000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %ConstCase{
        const: Vtc.Rate.f60(),
        ntsc: :None,
        playback: Ratio.new(60, 1),
        timebase: Ratio.new(60, 1)
      }
    ]

    for tc <- cases do
      const = tc.const
      @testCase tc

      test "#{const} const" do
        assert @testCase.ntsc == @testCase.const.ntsc
        assert @testCase.playback == @testCase.const.playback
        assert @testCase.timebase == Vtc.Framerate.timebase(@testCase.const)
      end
    end
  end
end
