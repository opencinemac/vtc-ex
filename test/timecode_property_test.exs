# Long property tests are put in their own module so they can be run concurrently.

defmodule Vtc.TimecodeTest.Properties.Parse.Helpers do
  @moduledoc false

  use ExUnit.Case
  use ExUnitProperties

  alias Vtc.Framerate
  alias Vtc.Utils.Rational

  @spec ratio() :: StreamData.t(Ratio.t())
  def ratio do
    map(
      {
        integer(),
        integer() |> filter(&(&1 != 0))
      },
      fn {numerator, denominator} -> Ratio.new(numerator, denominator) end
    )
  end

  @spec frame_rate_gen() :: StreamData.t(Framerate.t())
  def frame_rate_gen do
    map(
      {
        integer() |> filter(&(&1 > 0)),
        map(boolean(), fn
          true -> :non_drop
          false -> nil
        end)
      },
      fn {rate, ntsc} -> Framerate.new!(rate, ntsc) end
    )
  end

  @spec timecode_gen(Framerate.t()) :: StreamData.t(map())
  def timecode_gen(rate) do
    map(
      {
        integer(1..23),
        integer(0..59),
        integer(0..59),
        integer(0..((Framerate.timebase(rate) |> Rational.round()) - 1)),
        boolean()
      },
      fn {hours, minutes, seconds, frames, negative?} = values ->
        %{
          timecode_string: build_timecode_string(values, rate),
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          frames: frames,
          negative?: negative?
        }
      end
    )
  end

  @spec build_timecode_string(tuple(), Framerate.t()) :: String.t()
  def build_timecode_string(values, rate) do
    {hours, minutes, seconds, frames, negative?} = values

    add_frame_sep = fn values ->
      if rate.ntsc == :drop, do: List.replace_at(values, -2, ";"), else: values
    end

    timecode_string =
      [hours, minutes, seconds, frames]
      |> Enum.map(&Integer.to_string/1)
      |> Enum.map(&String.pad_leading(&1, 2, "0"))
      |> Enum.intersperse(":")
      |> then(add_frame_sep)
      |> List.to_string()

    if negative?, do: "-" <> timecode_string, else: timecode_string
  end

  @spec assert_frame_rounded(Timecode.t()) :: term()
  def assert_frame_rounded(timecode) do
    %{seconds: seconds, rate: %{playback: playback_rate}} = timecode

    seconds_per_frame =
      Ratio.new(Ratio.denominator(playback_rate), Ratio.numerator(playback_rate))

    assert {_, 0} = Rational.divmod(seconds, seconds_per_frame)
  end
end

defmodule Vtc.TimecodeTest.Properties.ParseRoundTripDrop do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Vtc.Framerate
  alias Vtc.Timecode

  import Vtc.TimecodeTest.Properties.Parse.Helpers

  describe "parse round trip" do
    property "timecode | ntsc | drop" do
      check all(
              rate_multiplier <- integer(1..10),
              rate <- (30 * rate_multiplier) |> Framerate.new!(:drop) |> constant(),
              timecode_values <- timecode_gen(rate),
              max_runs: 100
            ) do
        %{
          timecode_string: timecode_string,
          minutes: minutes,
          seconds: seconds,
          frames: frames
        } = timecode_values

        if frames < 2 * rate_multiplier and rem(minutes, 10) != 0 and seconds == 0 do
          assert_raise Timecode.ParseError, fn -> Timecode.with_frames!(timecode_string, rate) end
        else
          timecode = Timecode.with_frames!(timecode_string, rate)
          assert Timecode.timecode(timecode) == timecode_string
        end
      end
    end
  end
end

defmodule Vtc.TimecodeTest.Properties.ParseRoundTripNonDrop do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Vtc.Framerate
  alias Vtc.Timecode

  import Vtc.TimecodeTest.Properties.Parse.Helpers

  describe "parse round trip" do
    property "timecode | ntsc | non_drop" do
      check all(
              rate <- frame_rate_gen(),
              timecode_values <- timecode_gen(rate),
              max_runs: 100
            ) do
        %{timecode_string: timecode_string} = timecode_values
        timecode = Timecode.with_frames!(timecode_string, rate)
        assert Timecode.timecode(timecode) == timecode_string
      end
    end

    property "frames" do
      check all(
              frames <- integer(),
              rate <- frame_rate_gen(),
              max_runs: 20
            ) do
        timecode = Timecode.with_frames!(frames, rate)
        assert Timecode.frames(timecode) == frames
      end
    end

    property "seconds" do
      check all(
              rate <- frame_rate_gen() |> filter(&(&1.ntsc == nil)),
              seconds <- map(integer(), fn scalar -> Ratio.mult(rate.playback, scalar) end),
              max_runs: 20
            ) do
        timecode = Timecode.with_seconds!(seconds, rate)
        assert timecode.seconds == seconds
      end
    end
  end
end

defmodule Vtc.TimecodeTest.Properties.Rebase do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Vtc.Framerate
  alias Vtc.Timecode

  import Vtc.TimecodeTest.Properties.Parse.Helpers

  describe "#rebase/2" do
    property "round trip rebases do not lose accuracy" do
      run_rebase_property_test(fn timecode, new_rate ->
        assert {:ok, rebased} = Timecode.rebase(timecode, new_rate)
        rebased
      end)
    end
  end

  describe "#rebase!/2" do
    property "round trip rebases do not lose accuracy" do
      run_rebase_property_test(fn timecode, new_rate ->
        Timecode.rebase!(timecode, new_rate)
      end)
    end
  end

  @spec run_rebase_property_test((Timecode.t(), Framerate.t() -> Timecode.t())) :: term()
  defp run_rebase_property_test(do_reabase) do
    check all(
            frames <- integer(),
            original_rate_x <- integer(1..240),
            original_ntsc <- boolean(),
            target_rate_x <- integer(1..240),
            target_ntsc <- boolean(),
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
end

defmodule Vtc.TimecodeTest.Properties.Arithmatic do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Vtc.Framerate
  alias Vtc.Rates
  alias Vtc.Timecode

  import Vtc.TimecodeTest.Properties.Parse.Helpers

  describe "#compare/2" do
    property "if a.rate = b.rate then a and b comparison should equal the comparison of their frame count" do
      check all(
              [a_frames, b_frames] <- list_of(integer(), length: 2),
              rate_x <- integer(1..240),
              ntsc <- boolean(),
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

  property "add/sub symmetry" do
    check all(
            rate <- frame_rate_gen(),
            a_info <- rate |> timecode_gen() |> filter(&(not &1.negative?)),
            b_info <- rate |> timecode_gen() |> filter(&(not &1.negative?))
          ) do
      %{timecode_string: a_string} = a_info
      %{timecode_string: b_string} = b_info
      a = Timecode.with_frames!(a_string, rate)
      b = Timecode.with_frames!(b_string, rate)

      added = Timecode.add(a, b)
      assert Timecode.compare(added, a) == :gt
      assert Timecode.compare(added, b) == :gt

      subtracted = Timecode.sub(added, b)
      assert Timecode.compare(subtracted, a) == :eq
    end
  end

  describe "#mult/2" do
    property "always returns frame-rounded" do
      check all(
              rate <- frame_rate_gen(),
              timecode_values <- timecode_gen(rate),
              multiplier <- float()
            ) do
        %{timecode_string: timecode_string} = timecode_values
        a = Timecode.with_frames!(timecode_string, rate)

        assert %Timecode{rate: ^rate} = result = Timecode.mult(a, multiplier)
        assert_frame_rounded(result)
      end
    end

    property "basic comparisons" do
      check all(
              rate <- frame_rate_gen(),
              tc_info <- Rates.f23_98() |> timecode_gen() |> filter(&(not &1.negative?)),
              scalar <- ratio()
            ) do
        %{timecode_string: tc_string} = tc_info
        original = Timecode.with_frames!(tc_string, rate)
        multiplied = Timecode.mult(original, scalar)

        case {Ratio.compare(scalar, 0), Ratio.compare(scalar, 1)} do
          {:eq, _} -> assert multiplied == Timecode.with_frames!(0, rate)
          {_, :eq} -> assert Timecode.compare(multiplied, original) == :eq
          {_, :lt} -> assert Timecode.compare(multiplied, original) == :lt
          {_, :gt} -> assert Timecode.compare(multiplied, original) == :gt
        end
      end
    end
  end

  describe "#div/2" do
    property "always returns frame-rounded" do
      check all(
              rate <- frame_rate_gen(),
              timecode_values <- timecode_gen(rate),
              multiplier <- float() |> filter(&(&1 != 0))
            ) do
        %{timecode_string: timecode_string} = timecode_values
        a = Timecode.with_frames!(timecode_string, rate)

        assert %Timecode{rate: ^rate} = result = Timecode.div(a, multiplier)
        assert_frame_rounded(result)
      end
    end

    property "basic comparisons" do
      check all(
              rate <- frame_rate_gen(),
              tc_info <- rate |> timecode_gen() |> filter(&(not &1.negative?)),
              divisor <- ratio() |> filter(&(&1 != 0))
            ) do
        %{timecode_string: tc_string} = tc_info
        dividend = Timecode.with_frames!(tc_string, rate)
        quotient = Timecode.div(dividend, divisor)

        case {Ratio.compare(divisor, 0), Ratio.compare(divisor, 1)} do
          {:lt, _} -> assert Timecode.compare(quotient, dividend) == :lt
          {:gt, :lt} -> assert Timecode.compare(quotient, dividend) == :gt
          {_, :eq} -> assert Timecode.compare(quotient, dividend) == :eq
          {:gt, :gt} -> assert Timecode.compare(quotient, dividend) == :lt
        end
      end
    end
  end

  describe "#divmod/2" do
    property "quotient returns same as div/2" do
      check all(
              rate <- frame_rate_gen(),
              tc_info <- rate |> timecode_gen() |> filter(&(not &1.negative?)),
              divisor <- ratio() |> filter(&(&1 != 0))
            ) do
        %{timecode_string: tc_string} = tc_info
        dividend = Timecode.with_frames!(tc_string, rate)

        div_result = Timecode.div(dividend, divisor)
        {divmod_result, _} = Timecode.divmod(dividend, divisor)

        assert div_result == divmod_result
      end
    end
  end
end
