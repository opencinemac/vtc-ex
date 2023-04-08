defmodule Vtc.RangeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Vtc.Range
  alias Vtc.Rates
  alias Vtc.Timecode

  describe "#overlaps?/2" do
    @range_cases [
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"01:00:00:00", "02:00:00:00"},
        inclusive?: [true, false],
        expected: true
      },
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"01:30:00:00", "02:30:00:00"},
        inclusive?: [true, false],
        expected: true
      },
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"00:30:00:00", "02:30:00:00"},
        inclusive?: [true, false],
        expected: true
      },
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"01:15:00:00", "01:45:00:00"},
        inclusive?: [true, false],
        expected: true
      },
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"02:00:00:00", "03:00:00:00"},
        inclusive?: [true],
        expected: true
      },
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"02:00:00:00", "03:00:00:00"},
        inclusive?: [false],
        expected: false
      },
      %{
        range_01: {"00:00:00:00", "00:30:00:00"},
        range_02: {"01:00:00:00", "02:00:00:00"},
        inclusive?: [false],
        expected: false
      },
      %{
        range_01: {"00:00:00:00", "00:59:59:23"},
        range_02: {"01:00:00:00", "02:00:00:00"},
        inclusive?: [true],
        expected: false
      }
    ]

    for range_case <- @range_cases do
      @range_case range_case

      for inclusive? <- range_case.inclusive? do
        @inclusive? inclusive?

        test "#{inspect(range_case.range_01)} | #{inspect(range_case.range_02)} | inclusive? #{inclusive?} | #{range_case.expected}" do
          {in_01, out_01} = @range_case.range_01
          in_01 = Timecode.with_frames!(in_01, Rates.f23_98())
          out_01 = Timecode.with_frames!(out_01, Rates.f23_98())
          range_01 = %Range{in: in_01, out: out_01, out_inclusive?: @inclusive?}

          {in_02, out_02} = @range_case.range_02
          in_02 = Timecode.with_frames!(in_02, Rates.f23_98())
          out_02 = Timecode.with_frames!(out_02, Rates.f23_98())
          range_02 = %Range{in: in_02, out: out_02, out_inclusive?: @inclusive?}

          assert Range.overlaps?(range_01, range_02) == @range_case.expected
        end

        if range_case.range_01 != range_case.range_02 do
          test "#{inspect(range_case.range_02)} | #{inspect(range_case.range_01)} | inclusive? #{inclusive?} | #{range_case.expected}" do
            {in_01, out_01} = @range_case.range_01
            in_01 = Timecode.with_frames!(in_01, Rates.f23_98())
            out_01 = Timecode.with_frames!(out_01, Rates.f23_98())
            range_01 = %Range{in: in_01, out: out_01, out_inclusive?: @inclusive?}

            {in_02, out_02} = @range_case.range_02
            in_02 = Timecode.with_frames!(in_02, Rates.f23_98())
            out_02 = Timecode.with_frames!(out_02, Rates.f23_98())
            range_02 = %Range{in: in_02, out: out_02, out_inclusive?: @inclusive?}

            assert Range.overlaps?(range_02, range_01) == @range_case.expected
          end
        end

        test "-#{inspect(range_case.range_01)} | -#{inspect(range_case.range_02)} | inclusive? #{inclusive?} | #{range_case.expected}" do
          {out_01, in_01} = @range_case.range_01
          in_01 = in_01 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
          out_01 = out_01 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
          range_01 = %Range{in: in_01, out: out_01, out_inclusive?: @inclusive?}

          {out_02, in_02} = @range_case.range_02
          in_02 = in_02 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
          out_02 = out_02 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
          range_02 = %Range{in: in_02, out: out_02, out_inclusive?: @inclusive?}

          assert Range.overlaps?(range_01, range_02) == @range_case.expected
        end

        if range_case.range_01 != range_case.range_02 do
          test "-#{inspect(range_case.range_02)} | -#{inspect(range_case.range_01)} | inclusive? #{inclusive?} | #{range_case.expected}" do
            {out_01, in_01} = @range_case.range_01
            in_01 = in_01 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
            out_01 = out_01 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
            range_01 = %Range{in: in_01, out: out_01, out_inclusive?: @inclusive?}

            {out_02, in_02} = @range_case.range_02
            in_02 = in_02 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
            out_02 = out_02 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
            range_02 = %Range{in: in_02, out: out_02, out_inclusive?: @inclusive?}

            assert Range.overlaps?(range_02, range_01) == @range_case.expected
          end
        end
      end
    end
  end
end
