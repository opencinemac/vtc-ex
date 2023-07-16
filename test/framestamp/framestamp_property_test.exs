# Long property tests are put in their own module so they can be run concurrently.

defmodule Vtc.FramestampTest.Properties.Parse.Helpers do
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
        filter(integer(), &(&1 != 0))
      },
      fn {numerator, denominator} -> Ratio.new(numerator, denominator) end
    )
  end

  @spec frame_rate_gen() :: StreamData.t(Framerate.t())
  def frame_rate_gen do
    map(
      {
        filter(integer(), &(&1 > 0)),
        map(boolean(), fn
          true -> :non_drop
          false -> nil
        end)
      },
      fn
        {rate, :non_drop} -> Framerate.new!(rate, ntsc: :non_drop, coerce_ntsc?: true)
        {rate, nil} -> Framerate.new!(rate, ntsc: nil)
      end
    )
  end

  @spec timecode_gen(Framerate.t()) :: StreamData.t(map())
  def timecode_gen(rate) do
    map(
      {
        integer(1..23),
        integer(0..59),
        integer(0..59),
        integer(0..((rate |> Framerate.smpte_timebase() |> Rational.round()) - 1)),
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

  @spec assert_frame_rounded(Framestamp.t()) :: term()
  def assert_frame_rounded(framestamp) do
    %{seconds: seconds, rate: %{playback: playback_rate}} = framestamp

    seconds_per_frame = Ratio.new(Ratio.denominator(playback_rate), Ratio.numerator(playback_rate))

    assert %Ratio{numerator: 0, denominator: 1} = Rational.rem(seconds, seconds_per_frame)
  end
end

defmodule Vtc.FramestampTest.Properties.ParseRoundTripDrop do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Vtc.FramestampTest.Properties.Parse.Helpers

  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Rates
  alias Vtc.TestUtls.StreamDataVtc

  describe "parse round trip" do
    property "timecode | ntsc | drop" do
      check all(
              rate_multiplier <- integer(1..10),
              rate <- (30 * rate_multiplier) |> Framerate.new!(ntsc: :drop, coerce_ntsc?: true) |> constant(),
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
          assert_raise Framestamp.ParseError, fn -> Framestamp.with_frames!(timecode_string, rate) end
        else
          framestamp = Framestamp.with_frames!(timecode_string, rate)
          assert Framestamp.smpte_timecode(framestamp) == timecode_string
        end
      end
    end
  end

  property "timecode round trip" do
    check all(framestamp <- StreamDataVtc.framestamp(rate_opts: [type: [:whole, :non_drop, :drop]])) do
      timecode_str = Framestamp.smpte_timecode(framestamp)

      assert {:ok, result} = Framestamp.with_frames(timecode_str, framestamp.rate)
      assert result == framestamp
    end
  end

  property "59.94 frames round trip" do
    check all(frames <- StreamData.integer(-5_178_816..5_178_816)) do
      assert {:ok, framestamp} = Framestamp.with_frames(frames, Rates.f59_94_df())
      Framestamp.frames(framestamp) == frames

      assert {:ok, ^framestamp} = Framestamp.with_frames(frames, Rates.f59_94_df())
    end
  end

  property "rounded seconds successfully parsed by `with_seconds`, round: off" do
    check all(
            seconds <- StreamDataVtc.rational(),
            framerate <- StreamDataVtc.framerate()
          ) do
      assert {:ok, framestamp} = Framestamp.with_seconds(seconds, framerate)
      assert {:ok, ^framestamp} = Framestamp.with_seconds(framestamp.seconds, framerate, round: :off)
    end
  end
end

defmodule Vtc.FramestampTest.Properties.ParseRoundTripNonDrop do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Vtc.FramestampTest.Properties.Parse.Helpers

  alias Vtc.Framerate
  alias Vtc.Framestamp

  describe "parse round trip" do
    property "timecode | ntsc | non_drop" do
      check all(
              rate <- frame_rate_gen(),
              timecode_values <- timecode_gen(rate),
              max_runs: 100
            ) do
        %{timecode_string: timecode_string} = timecode_values
        framestamp = Framestamp.with_frames!(timecode_string, rate)
        assert Framestamp.smpte_timecode(framestamp) == timecode_string
      end
    end

    property "frames" do
      check all(
              frames <- integer(),
              rate <- frame_rate_gen(),
              max_runs: 20
            ) do
        framestamp = Framestamp.with_frames!(frames, rate)
        assert Framestamp.frames(framestamp) == frames
      end
    end

    property "seconds" do
      check all(
              rate <- filter(frame_rate_gen(), &(&1.ntsc == nil)),
              seconds <-
                map(integer(), fn scalar -> Ratio.mult(rate.playback, Ratio.new(scalar)) end),
              max_runs: 20
            ) do
        framestamp = Framestamp.with_seconds!(seconds, rate)
        assert framestamp.seconds == seconds
      end
    end
  end
end

defmodule Vtc.FramestampTest.Properties.Rebase do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Vtc.FramestampTest.Properties.Parse.Helpers

  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.TestUtls.StreamDataVtc

  describe "#rebase/2" do
    property "round trip rebases do not lose accuracy" do
      check all(
              framestamp <- StreamDataVtc.framestamp(),
              new_rate <- StreamDataVtc.framerate(),
              max_runs: 20
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          assert rebased = Framestamp.rebase!(framestamp, new_rate)
          assert ^framestamp = Framestamp.rebase!(rebased, framestamp.rate)
        end)
      end
    end
  end
end

defmodule Vtc.FramestampTest.Properties.Arithmetic do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Vtc.FramestampTest.Properties.Parse.Helpers

  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Rates
  alias Vtc.TestUtls.StreamDataVtc

  property "add/sub symmetry" do
    check all(
            rate <- StreamDataVtc.framerate(),
            a <- StreamDataVtc.framestamp(non_negative?: true, rate: rate),
            b <- StreamDataVtc.framestamp(non_negative?: true, rate: rate)
          ) do
      added = Framestamp.add(a, b)

      assert Framestamp.compare(added, a) == :gt
      assert Framestamp.compare(added, b) == :gt

      subtracted = Framestamp.sub(added, b)
      assert Framestamp.compare(subtracted, a) == :eq
    end
  end

  describe "#mult/2" do
    property "always returns frame-rounded" do
      check all(
              a <-
                StreamData.filter(
                  StreamDataVtc.framestamp(rate_opts: [type: [:whole, :drop, :non_drop]]),
                  &Ratio.gt?(&1.rate.playback, Ratio.new(1))
                ),
              multiplier <- float()
            ) do
        %{rate: rate} = a

        assert %Framestamp{rate: ^rate} = result = Framestamp.mult(a, multiplier)
        assert_frame_rounded(result)
      end
    end

    property "basic comparisons" do
      check all(
              rate <- StreamDataVtc.framerate(),
              original <- StreamDataVtc.framestamp(non_negative?: true, rate: rate),
              scalar <- StreamDataVtc.rational()
            ) do
        multiplied = Framestamp.mult(original, scalar)

        case {Ratio.compare(scalar, 0), Ratio.compare(scalar, 1)} do
          {:eq, _} -> assert multiplied == Framestamp.with_frames!(0, rate)
          {_, :eq} -> assert Framestamp.compare(multiplied, original) == :eq
          {_, :lt} -> assert Framestamp.compare(multiplied, original) == :lt
          {_, :gt} -> assert Framestamp.compare(multiplied, original) == :gt
        end
      end
    end
  end

  describe "#div/2" do
    property "always returns frame-rounded" do
      check all(
              a <-
                StreamData.filter(
                  StreamDataVtc.framestamp(rate_opts: [type: [:whole, :drop, :non_drop]]),
                  &Ratio.gt?(&1.rate.playback, Ratio.new(1))
                ),
              multiplier <- filter(float(), &(&1 != 0))
            ) do
        %{rate: rate} = a

        assert %Framestamp{rate: ^rate} = result = Framestamp.div(a, multiplier)
        assert_frame_rounded(result)
      end
    end

    property "basic comparisons" do
      check all(
              rate <- frame_rate_gen(),
              tc_info <- rate |> timecode_gen() |> filter(&(not &1.negative?)),
              divisor <- filter(ratio(), &(&1 != Ratio.new(0)))
            ) do
        %{timecode_string: tc_string} = tc_info
        dividend = Framestamp.with_frames!(tc_string, rate)
        quotient = Framestamp.div(dividend, divisor)

        case {Ratio.compare(divisor, 0), Ratio.compare(divisor, 1)} do
          {:lt, _} -> assert Framestamp.compare(quotient, dividend) == :lt
          {:gt, :lt} -> assert Framestamp.compare(quotient, dividend) == :gt
          {_, :eq} -> assert Framestamp.compare(quotient, dividend) == :eq
          {:gt, :gt} -> assert Framestamp.compare(quotient, dividend) == :lt
        end
      end
    end

    property "abs(div(-a, +b)) = abs(div(+a, +b))" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true),
              divisor <- StreamDataVtc.rational(positive?: true)
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          neg_dividend = Framestamp.minus(dividend)

          pos_quotient = Framestamp.div(dividend, divisor)
          neg_quotient = Framestamp.div(neg_dividend, divisor)

          zero = Framestamp.with_frames!(0, dividend.rate)
          assert Framestamp.lte?(neg_quotient, zero)

          assert Framestamp.abs(pos_quotient) == Framestamp.abs(neg_quotient)
        end)
      end
    end

    property "abs(div(+a, -b)) = abs(div(+a, +b))" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true),
              divisor <- StreamDataVtc.rational(positive?: true)
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          neg_divisor = Ratio.minus(divisor)

          pos_quotient = Framestamp.div(dividend, divisor)
          neg_quotient = Framestamp.div(dividend, neg_divisor)

          zero = Framestamp.with_frames!(0, dividend.rate)
          assert Framestamp.lte?(neg_quotient, zero)

          assert Framestamp.abs(pos_quotient) == Framestamp.abs(neg_quotient)
        end)
      end
    end

    property "abs(div(-Bencheea, -b)) = abs(div(+a, +b))" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true),
              divisor <- StreamDataVtc.rational(positive?: true)
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          neg_dividend = Framestamp.minus(dividend)
          neg_divisor = Ratio.minus(divisor)

          pos_quotient = Framestamp.div(dividend, divisor)
          neg_quotient = Framestamp.div(neg_dividend, neg_divisor)

          zero = Framestamp.with_frames!(0, dividend.rate)
          assert Framestamp.gte?(neg_quotient, zero)

          assert Framestamp.abs(pos_quotient) == Framestamp.abs(neg_quotient)
        end)
      end
    end
  end

  describe "#divrem/2" do
    property "quotient returns same as div/3 with :trunc" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true, rate_opts: [type: [:whole, :drop, :non_drop]]),
              divisor <- filter(StreamDataVtc.rational(), &(&1 != Ratio.new(0)))
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          div_result = Framestamp.div(dividend, divisor, round: :trunc)
          {divrem_result, _} = Framestamp.divrem(dividend, divisor)

          assert divrem_result == div_result
        end)
      end
    end

    property "abs(divrem(-a, +b)) = abs(divrem(+a, +b))" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true),
              divisor <- StreamDataVtc.rational(positive?: true)
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          neg_dividend = Framestamp.minus(dividend)

          {pos_quotient, pos_remainder} = Framestamp.divrem(dividend, divisor)
          {neg_quotient, neg_remainder} = Framestamp.divrem(neg_dividend, divisor)

          zero = Framestamp.with_frames!(0, dividend.rate)

          assert Framestamp.lte?(neg_quotient, zero)
          assert Framestamp.lte?(neg_remainder, zero)

          assert Framestamp.abs(pos_quotient) == Framestamp.abs(neg_quotient)
          assert Framestamp.abs(pos_remainder) == Framestamp.abs(neg_remainder)
        end)
      end
    end

    property "abs(divrem(+a, -b)) = divrem(div(+a, +b))" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true),
              divisor <- StreamDataVtc.rational(positive?: true)
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          neg_divisor = Ratio.minus(divisor)

          {pos_quotient, pos_remainder} = Framestamp.divrem(dividend, divisor)
          {neg_quotient, neg_remainder} = Framestamp.divrem(dividend, neg_divisor)

          zero = Framestamp.with_frames!(0, dividend.rate)

          assert Framestamp.lte?(neg_quotient, zero)
          assert Framestamp.gte?(neg_remainder, zero)

          assert Framestamp.abs(pos_quotient) == Framestamp.abs(neg_quotient)
          assert Framestamp.abs(pos_remainder) == Framestamp.abs(neg_remainder)
        end)
      end
    end

    property "abs(divrem(-a, -b)) = abs(divrem(+a, +b))" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true),
              divisor <- StreamDataVtc.rational(positive?: true)
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          neg_dividend = Framestamp.minus(dividend)
          neg_divisor = Ratio.minus(divisor)

          {pos_quotient, pos_remainder} = Framestamp.divrem(dividend, divisor)
          {neg_quotient, neg_remainder} = Framestamp.divrem(neg_dividend, neg_divisor)

          zero = Framestamp.with_frames!(0, dividend.rate)

          assert Framestamp.gte?(neg_quotient, zero)
          assert Framestamp.lte?(neg_remainder, zero)

          assert Framestamp.abs(pos_quotient) == Framestamp.abs(neg_quotient)
          assert Framestamp.abs(pos_remainder) == Framestamp.abs(neg_remainder)
        end)
      end
    end
  end

  describe "#rem/2" do
    property "returns same as divrem/3" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true),
              divisor <- filter(StreamDataVtc.rational(), &(&1 != Ratio.new(0)))
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          {_, divrem_result} = Framestamp.divrem(dividend, divisor)
          rem_result = Framestamp.rem(dividend, divisor)

          assert rem_result == divrem_result
        end)
      end
    end

    property "abs(rem(-a, +b)) = abs(rem(+a, +b))" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true),
              divisor <- StreamDataVtc.rational(positive?: true)
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          neg_dividend = Framestamp.minus(dividend)

          pos_result = Framestamp.rem(dividend, divisor)
          neg_result = Framestamp.rem(neg_dividend, divisor)

          zero = Framestamp.with_frames!(0, dividend.rate)

          assert Framestamp.lte?(neg_result, zero)
          assert Framestamp.abs(pos_result) == Framestamp.abs(neg_result)
        end)
      end
    end

    property "abs(rem(a, -b)) = abs(rem(+a, +b))" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true),
              divisor <- StreamDataVtc.rational(positive?: true)
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          neg_divisor = Ratio.minus(divisor)

          pos_result = Framestamp.rem(dividend, divisor)
          neg_result = Framestamp.rem(dividend, neg_divisor)

          zero = Framestamp.with_frames!(0, dividend.rate)

          assert Framestamp.gte?(neg_result, zero)
          assert Framestamp.abs(pos_result) == Framestamp.abs(neg_result)
        end)
      end
    end

    property "abs(rem(-a, -b)) = abs(rem(+a, +b))" do
      check all(
              dividend <- StreamDataVtc.framestamp(non_negative?: true),
              divisor <- StreamDataVtc.rational(positive?: true)
            ) do
        StreamDataVtc.run_test_rescue_drop_overflow(fn ->
          neg_dividend = Framestamp.minus(dividend)
          neg_divisor = Ratio.minus(divisor)

          pos_result = Framestamp.rem(dividend, divisor)
          neg_result = Framestamp.rem(neg_dividend, neg_divisor)

          zero = Framestamp.with_frames!(0, dividend.rate)

          assert Framestamp.lte?(neg_result, zero)
          assert Framestamp.abs(pos_result) == Framestamp.abs(neg_result)
        end)
      end
    end
  end

  describe "#abs/2" do
    property "returns input of negate/1" do
      check all(positive <- StreamDataVtc.framestamp(non_negative?: true)) do
        negative = Framestamp.minus(positive)
        assert Framestamp.abs(positive) == Framestamp.abs(negative)
      end
    end
  end
end

defmodule Vtc.FramestampTest.Properties.Compare do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Rates

  property "#if a.rate = b.rate then a and b comparison should equal the comparison of their frame count" do
    check all(
            [a_frames, b_frames] <- list_of(integer(), length: 2),
            rate_x <- integer(1..240),
            ntsc? <- boolean(),
            max_runs: 100
          ) do
      ntsc = if ntsc?, do: :non_drop, else: nil
      rate = Framerate.new!(rate_x, ntsc: ntsc, coerce_ntsc?: ntsc?)

      a = Framestamp.with_frames!(a_frames, rate)
      b = Framestamp.with_frames!(b_frames, rate)

      expected =
        cond do
          a_frames == b_frames -> :eq
          a_frames < b_frames -> :lt
          true -> :gt
        end

      assert Framestamp.compare(a, b) == expected
    end
  end

  property "#eq?/2 always matches compare/2" do
    check all([a_frames, b_frames] <- list_of(integer(), length: 2)) do
      a = Framestamp.with_frames!(a_frames, Rates.f23_98())
      b = Framestamp.with_frames!(b_frames, Rates.f23_98())

      assert Framestamp.eq?(a, b) == (a_frames == b_frames)
    end
  end

  property "#lt?/2 always matches compare/2" do
    check all([a_frames, b_frames] <- list_of(integer(), length: 2)) do
      a = Framestamp.with_frames!(a_frames, Rates.f23_98())
      b = Framestamp.with_frames!(b_frames, Rates.f23_98())

      assert Framestamp.lt?(a, b) == a_frames < b_frames
    end
  end

  property "#lte?/2 always matches compare/2" do
    check all([a_frames, b_frames] <- list_of(integer(), length: 2)) do
      a = Framestamp.with_frames!(a_frames, Rates.f23_98())
      b = Framestamp.with_frames!(b_frames, Rates.f23_98())

      assert Framestamp.lte?(a, b) == a_frames <= b_frames
    end
  end

  property "#gt?/2 always matches compare/2" do
    check all([a_frames, b_frames] <- list_of(integer(), length: 2)) do
      a = Framestamp.with_frames!(a_frames, Rates.f23_98())
      b = Framestamp.with_frames!(b_frames, Rates.f23_98())

      assert Framestamp.gt?(a, b) == a_frames > b_frames
    end
  end

  property "#gte?/2 always matches frame comparson" do
    check all([a_frames, b_frames] <- list_of(integer(), length: 2)) do
      a = Framestamp.with_frames!(a_frames, Rates.f23_98())
      b = Framestamp.with_frames!(b_frames, Rates.f23_98())

      assert Framestamp.gte?(a, b) == a_frames >= b_frames
    end
  end
end
