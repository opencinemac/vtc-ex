defmodule Vtc.FramerateTest do
  @moduledoc false
  use Vtc.Test.Support.TestCase
  use ExUnitProperties

  alias Vtc.Framerate
  alias Vtc.Framerate.ParseError
  alias Vtc.Rates

  setup [:setup_test_case]

  describe "#parse" do
    test_cases = [
      %{
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
          "24000/1001"
        ],
        ntsc: :non_drop,
        coerce_ntsc?: true,
        playback: Ratio.new(24_000, 1001),
        timebase: Ratio.new(24, 1)
      },
      %{
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
          "30000/1001"
        ],
        ntsc: :drop,
        coerce_ntsc?: true,
        playback: Ratio.new(30_000, 1001),
        timebase: Ratio.new(30, 1)
      },
      %{
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
          "60000/1001"
        ],
        ntsc: :drop,
        coerce_ntsc?: true,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %{
        name: "11000/1001 NTSC",
        inputs: [
          Ratio.new(11_000, 1001),
          "11000/1001"
        ],
        ntsc: :non_drop,
        coerce_ntsc?: false,
        playback: Ratio.new(11_000, 1001),
        timebase: Ratio.new(11, 1)
      },
      %{
        name: "24 fps",
        inputs: [
          Ratio.new(24, 1),
          24,
          24.0,
          "24/1",
          "24.0"
        ],
        ntsc: nil,
        coerce_ntsc?: false,
        playback: Ratio.new(24, 1),
        timebase: Ratio.new(24, 1)
      },
      %{
        name: "error - bad drop",
        inputs: [
          Ratio.new(24, 1),
          24,
          "24/1",
          "29"
        ],
        ntsc: :drop,
        coerce_ntsc?: true,
        err: %Framerate.ParseError{reason: :bad_drop_rate},
        err_msg: "drop-frame rates must be divisible by 30000/1001"
      },
      %{
        name: "error - uknown format",
        inputs: [
          "notarate"
        ],
        ntsc: :drop,
        coerce_ntsc?: true,
        err: %Framerate.ParseError{reason: :unrecognized_format},
        err_msg: "framerate string format not recognized"
      },
      %{
        name: "error - unknown format",
        inputs: [
          24
        ],
        ntsc: :NotAnNtsc,
        coerce_ntsc?: false,
        err: %Framerate.ParseError{reason: :invalid_ntsc},
        err_msg: "ntsc is not a valid atom. must be :non_drop, :drop, or nil"
      },
      %{
        name: "error - imprecise",
        inputs: [
          23.98,
          "23.98"
        ],
        ntsc: nil,
        coerce_ntsc?: false,
        err: %Framerate.ParseError{reason: :imprecise},
        err_msg: "non-whole floats are not precise enough to create a non-NTSC Framerate"
      }
    ]

    test_cases =
      Enum.flat_map(test_cases, fn test_case ->
        for {input, index} <- Enum.with_index(test_case.inputs) do
          test_case
          |> Map.put(:input, input)
          |> Map.put(:name, "#{test_case.name} - #{index}: #{inspect(input)} - new")
        end
      end)

    for test_case <- test_cases do
      table_test "new/1 | #{test_case.name}", test_case, context do
        %{test_case: test_case, input: input, ntsc: ntsc, coerce_ntsc?: coerce_ntsc?} = context

        case Framerate.new(input, ntsc: ntsc, coerce_ntsc?: coerce_ntsc?) do
          {:ok, rate} ->
            check_parsed(test_case, rate)

          {:error, err} ->
            expected_reason =
              case context do
                %{err: %{reason: reason}} -> reason
                _ -> "no error expected"
              end

            expected_message = Map.get(context, :err_msg, nil)

            assert err.reason == expected_reason
            assert Framerate.ParseError.message(err) == expected_message
        end
      end

      table_test "new!/1 | #{test_case.name}", test_case, context do
        %{test_case: test_case, input: input, ntsc: ntsc, coerce_ntsc?: coerce_ntsc?} = context

        if is_map_key(test_case, :err) do
          function = fn -> Framerate.new!(input, ntsc: ntsc, coerce_ntsc?: coerce_ntsc?) end
          assert_raise Framerate.ParseError, function
        else
          rate = Framerate.new!(input, ntsc: ntsc, coerce_ntsc?: coerce_ntsc?)
          check_parsed(test_case, rate)
        end
      end
    end

    test_cases = [
      %{input: Ratio.new(24_000, 1002)},
      %{input: 24},
      %{input: 24_000 / 1002},
      %{input: 24_000 / 1001}
    ]

    for test_case <- test_cases do
      table_test "coerce_ntsc?: error on #{inspect(test_case.input)}", test_case, context do
        %{input: input} = context
        expected_message = "NTSC rates must be equivalent to `(timebase * 1000)/1001` when :coerce_ntsc? is false"

        assert {:error, error} = Framerate.new(input, ntsc: :non_drop)
        assert error.reason == :invalid_ntsc_rate
        assert ParseError.message(error) == expected_message
      end
    end

    @spec check_parsed(map(), Framerate.t()) :: nil
    defp check_parsed(test_case, parsed) do
      assert test_case.playback == parsed.playback
      assert test_case.timebase == Framerate.timebase(parsed)
      assert test_case.ntsc == parsed.ntsc
    end

    property "parse NTSC, non-drop rates" do
      check all(timebase <- StreamData.positive_integer()) do
        playback = Ratio.new(timebase * 1000, 1001)

        assert {:ok, framerate} = Framerate.new(playback, ntsc: :non_drop)
        assert framerate.playback == playback
        assert framerate.ntsc == :non_drop
      end
    end
  end

  describe "#consts" do
    use ExUnit.Case, async: true

    alias Vtc.Rates

    test_cases = [
      %{
        const: Rates.f23_98(),
        ntsc: :non_drop,
        playback: Ratio.new(24_000, 1001),
        timebase: Ratio.new(24, 1)
      },
      %{
        const: Rates.f24(),
        ntsc: nil,
        playback: Ratio.new(24, 1),
        timebase: Ratio.new(24, 1)
      },
      %{
        const: Rates.f29_97_ndf(),
        ntsc: :non_drop,
        playback: Ratio.new(30_000, 1001),
        timebase: Ratio.new(30, 1)
      },
      %{
        const: Rates.f29_97_df(),
        ntsc: :drop,
        playback: Ratio.new(30_000, 1001),
        timebase: Ratio.new(30, 1)
      },
      %{
        const: Rates.f30(),
        ntsc: nil,
        playback: Ratio.new(30, 1),
        timebase: Ratio.new(30, 1)
      },
      %{
        const: Rates.f47_95(),
        ntsc: :non_drop,
        playback: Ratio.new(48_000, 1001),
        timebase: Ratio.new(48, 1)
      },
      %{
        const: Rates.f48(),
        ntsc: nil,
        playback: Ratio.new(48, 1),
        timebase: Ratio.new(48, 1)
      },
      %{
        const: Rates.f59_94_ndf(),
        ntsc: :non_drop,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %{
        const: Rates.f59_94_df(),
        ntsc: :drop,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60, 1)
      },
      %{
        const: Rates.f60(),
        ntsc: nil,
        playback: Ratio.new(60, 1),
        timebase: Ratio.new(60, 1)
      }
    ]

    for test_case <- test_cases do
      table_test "#{test_case.const} const", test_case, context do
        %{ntsc: ntsc, playback: playback, timebase: timebase, const: const} = context

        assert ntsc == const.ntsc
        assert playback == const.playback
        assert timebase == Framerate.timebase(const)
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
