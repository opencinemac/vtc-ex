defmodule Vtc.FramerateTest do
  @moduledoc false
  use Vtc.Test.Support.TestCase
  use ExUnitProperties

  alias Vtc.Framerate
  alias Vtc.Framerate.ParseError
  alias Vtc.Rates

  describe "#parse" do
    parse_table = [
      %{
        name: "23.98 NTSC",
        inputs: [
          Ratio.new(24),
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
        timebase: Ratio.new(24)
      },
      %{
        name: "29.97 NTSC DF",
        inputs: [
          Ratio.new(30),
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
        timebase: Ratio.new(30)
      },
      %{
        name: "59.94 NTSC DF",
        inputs: [
          Ratio.new(60),
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
        timebase: Ratio.new(60)
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
        timebase: Ratio.new(11)
      },
      %{
        name: "24 fps",
        inputs: [
          Ratio.new(24),
          24,
          24.0,
          "24/1",
          "24.0"
        ],
        ntsc: nil,
        coerce_ntsc?: false,
        playback: Ratio.new(24),
        timebase: Ratio.new(24)
      },
      %{
        name: "error - non-positive | true",
        inputs: [
          Ratio.new(0),
          Ratio.new(-24, 1),
          0,
          -24,
          "0/1",
          "-24/1",
          0.0
        ],
        ntsc: :non_drop,
        coerce_ntsc?: true,
        err: %Framerate.ParseError{reason: :non_positive},
        err_msg: "must be positive"
      },
      %{
        name: "error - non-positive | :non_drop",
        inputs: [
          Ratio.new(0, 1001),
          Ratio.new(-24_000, 1001),
          0,
          -24,
          "0/1001",
          "-24000/1001",
          0.0,
          -23.98
        ],
        ntsc: :non_drop,
        coerce_ntsc?: true,
        err: %Framerate.ParseError{reason: :non_positive},
        err_msg: "must be positive"
      },
      %{
        name: "error - non-positive | :drop",
        inputs: [
          Ratio.new(0, 1001),
          Ratio.new(-30_000, 1001),
          0,
          -39,
          "0/1001",
          "-30000/1001",
          0.0,
          -29.97
        ],
        ntsc: :drop,
        coerce_ntsc?: true,
        err: %Framerate.ParseError{reason: :non_positive},
        err_msg: "must be positive"
      },
      %{
        name: "error - bad drop",
        inputs: [
          Ratio.new(24),
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

    new_table =
      Enum.flat_map(parse_table, fn test_case ->
        for input <- test_case.inputs do
          Map.put(test_case, :input, input)
        end
      end)

    table_test "new/1 | <%= name %>", new_table, test_case do
      %{input: input, ntsc: ntsc, coerce_ntsc?: coerce_ntsc?} = test_case

      case Framerate.new(input, ntsc: ntsc, coerce_ntsc?: coerce_ntsc?) do
        {:ok, rate} ->
          check_parsed(test_case, rate)

        {:error, err} ->
          expected_reason =
            case test_case do
              %{err: %{reason: reason}} -> reason
              _ -> "no error expected"
            end

          expected_message = Map.get(test_case, :err_msg, nil)

          assert err.reason == expected_reason
          assert Framerate.ParseError.message(err) == expected_message
      end
    end

    table_test "new!/1 | <%= name %>", new_table, test_case do
      %{test_case: test_case, input: input, ntsc: ntsc, coerce_ntsc?: coerce_ntsc?} = test_case

      if is_map_key(test_case, :err) do
        function = fn -> Framerate.new!(input, ntsc: ntsc, coerce_ntsc?: coerce_ntsc?) end
        assert_raise Framerate.ParseError, function
      else
        rate = Framerate.new!(input, ntsc: ntsc, coerce_ntsc?: coerce_ntsc?)
        check_parsed(test_case, rate)
      end
    end

    coerce_ntsc_table = [
      %{input: Ratio.new(24_000, 1002)},
      %{input: 24},
      %{input: 24_000 / 1002},
      %{input: 24_000 / 1001}
    ]

    table_test "coerce_ntsc?: error on <%= input %>", coerce_ntsc_table, test_case do
      %{input: input} = test_case
      expected_message = "NTSC rates must be equivalent to `(timebase * 1000)/1001` when :coerce_ntsc? is false"

      assert {:error, error} = Framerate.new(input, ntsc: :non_drop)
      assert error.reason == :invalid_ntsc_rate
      assert ParseError.message(error) == expected_message
    end

    @spec check_parsed(map(), Framerate.t()) :: nil
    defp check_parsed(test_case, parsed) do
      assert test_case.playback == parsed.playback
      assert test_case.timebase == Framerate.smpte_timebase(parsed)
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

    consts_table = [
      %{
        const: Rates.f23_98(),
        ntsc: :non_drop,
        playback: Ratio.new(24_000, 1001),
        timebase: Ratio.new(24)
      },
      %{
        const: Rates.f24(),
        ntsc: nil,
        playback: Ratio.new(24),
        timebase: Ratio.new(24)
      },
      %{
        const: Rates.f29_97_ndf(),
        ntsc: :non_drop,
        playback: Ratio.new(30_000, 1001),
        timebase: Ratio.new(30)
      },
      %{
        const: Rates.f29_97_df(),
        ntsc: :drop,
        playback: Ratio.new(30_000, 1001),
        timebase: Ratio.new(30)
      },
      %{
        const: Rates.f30(),
        ntsc: nil,
        playback: Ratio.new(30),
        timebase: Ratio.new(30)
      },
      %{
        const: Rates.f47_95(),
        ntsc: :non_drop,
        playback: Ratio.new(48_000, 1001),
        timebase: Ratio.new(48)
      },
      %{
        const: Rates.f48(),
        ntsc: nil,
        playback: Ratio.new(48),
        timebase: Ratio.new(48)
      },
      %{
        const: Rates.f59_94_ndf(),
        ntsc: :non_drop,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60)
      },
      %{
        const: Rates.f59_94_df(),
        ntsc: :drop,
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60)
      },
      %{
        const: Rates.f60(),
        ntsc: nil,
        playback: Ratio.new(60),
        timebase: Ratio.new(60)
      }
    ]

    table_test "<%= const %>", consts_table, test_case do
      %{ntsc: ntsc, playback: playback, timebase: timebase, const: const} = test_case

      assert ntsc == const.ntsc
      assert playback == const.playback
      assert timebase == Framerate.smpte_timebase(const)
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
