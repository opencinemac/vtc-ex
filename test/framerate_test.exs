defmodule Vtc.FramerateTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Vtc.TestSetups

  alias Vtc.Framerate
  alias Vtc.Rates

  setup [:setup_test_case]

  describe "#parse" do
    cases = [
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
        playback: Ratio.new(60_000, 1001),
        timebase: Ratio.new(60, 1)
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
        err: %Framerate.ParseError{reason: :bad_drop_rate},
        err_msg: "drop-frame rates must be divisible by 30000/1001"
      },
      %{
        name: "error - uknown format",
        inputs: [
          "notarate"
        ],
        ntsc: :drop,
        err: %Framerate.ParseError{reason: :unrecognized_format},
        err_msg: "framerate string format not recognized"
      },
      %{
        name: "error - unknown format",
        inputs: [
          24
        ],
        ntsc: :NotAnNtsc,
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
        err: %Framerate.ParseError{reason: :imprecise},
        err_msg: "non-whole floats are not precise enough to create a non-NTSC Framerate"
      }
    ]

    for this_case <- cases do
      case_name = this_case.name

      for {input_case, i} <- Enum.with_index(this_case.inputs) do
        @tag test_case: this_case
        @tag input: input_case
        test "#{case_name} - #{i}: #{inspect(input_case)} - new", context do
          %{test_case: test_case, input: input, ntsc: ntsc} = context

          case Framerate.new(input, ntsc: ntsc) do
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

        @tag test_case: this_case
        @tag input: input_case
        test "#{case_name} - #{i}: #{inspect(input_case)} - new!", context do
          %{test_case: test_case, input: input, ntsc: ntsc} = context

          if is_map_key(test_case, :err) do
            function = fn -> Framerate.new!(input, ntsc: ntsc) end
            assert_raise Framerate.ParseError, function
          else
            rate = Framerate.new!(input, ntsc: ntsc)
            check_parsed(test_case, rate)
          end
        end
      end
    end

    @spec check_parsed(map(), Framerate.t()) :: nil
    defp check_parsed(test_case, parsed) do
      assert test_case.playback == parsed.playback
      assert test_case.timebase == Framerate.timebase(parsed)
      assert test_case.ntsc == parsed.ntsc
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
      @tag test_case: test_case
      test "#{test_case.const} const", context do
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
