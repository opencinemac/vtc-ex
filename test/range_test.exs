defmodule Vtc.RangeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Vtc.Range
  alias Vtc.Rates
  alias Vtc.Timecode

  describe "new/3" do
    test "successfully created a new range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, tc_out)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :exclusive
    end

    test "successfully created a new range with inclusive out" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, tc_out, out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :inclusive
    end

    test "successfully created a zero-length range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, tc_out)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :exclusive
    end

    test "successfully created a zero-length inclusive range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("00:59:59:23", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, tc_out, out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :inclusive
    end

    test "fails when out is less than in" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("00:59:59:23", Rates.f23_98())

      assert {:error, error} = Range.new(tc_in, tc_out)
      assert Exception.message(error) == "`tc_out` must be greater than or equal to `tc_in`"
    end

    test "fails when rates are not the same" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f24())

      assert {:error, error} = Range.new(tc_in, tc_out)
      assert Exception.message(error) == "`tc_in` and `tc_out` must have same `rate`"
    end
  end

  describe "new!/3" do
    test "successfully created a new range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(tc_in, tc_out)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :exclusive
    end

    test "successfully created a new range with inclusive out" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(tc_in, tc_out, out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :inclusive
    end

    test "successfully created a zero-length range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      assert range = Range.new!(tc_in, tc_out)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :exclusive
    end

    test "successfully created a zero-length inclusive range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("00:59:59:23", Rates.f23_98())

      assert range = Range.new!(tc_in, tc_out, out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :inclusive
    end

    test "fails when out is less than in" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("00:59:59:23", Rates.f23_98())

      error = assert_raise(ArgumentError, fn -> Range.new!(tc_in, tc_out) end)
      assert Exception.message(error) == "`tc_out` must be greater than or equal to `tc_in`"
    end

    test "fails when rates are not the same" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f24())

      error = assert_raise(ArgumentError, fn -> Range.new!(tc_in, tc_out) end)
      assert Exception.message(error) == "`tc_in` and `tc_out` must have same `rate`"
    end
  end

  describe "#overlaps?/2" do
    @range_cases [
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"01:00:00:00", "02:00:00:00"},
        out_type: [:inclusive, :exclusive],
        expected: true
      },
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"01:30:00:00", "02:30:00:00"},
        out_type: [:inclusive, :exclusive],
        expected: true
      },
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"00:30:00:00", "02:30:00:00"},
        out_type: [:inclusive, :exclusive],
        expected: true
      },
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"01:15:00:00", "01:45:00:00"},
        out_type: [:inclusive, :exclusive],
        expected: true
      },
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"02:00:00:00", "03:00:00:00"},
        out_type: [:inclusive],
        expected: true
      },
      %{
        range_01: {"01:00:00:00", "02:00:00:00"},
        range_02: {"02:00:00:00", "03:00:00:00"},
        out_type: [:exclusive],
        expected: false
      },
      %{
        range_01: {"00:00:00:00", "00:30:00:00"},
        range_02: {"01:00:00:00", "02:00:00:00"},
        out_type: [:exclusive],
        expected: false
      },
      %{
        range_01: {"00:00:00:00", "00:59:59:23"},
        range_02: {"01:00:00:00", "02:00:00:00"},
        out_type: [:inclusive],
        expected: false
      }
    ]

    for range_case <- @range_cases do
      @range_case range_case

      for out_type <- range_case.out_type do
        @out_type out_type

        test "#{inspect(range_case.range_01)} | #{inspect(range_case.range_02)} | out #{out_type} | #{range_case.expected}" do
          {in_01, out_01} = @range_case.range_01
          in_01 = Timecode.with_frames!(in_01, Rates.f23_98())
          out_01 = Timecode.with_frames!(out_01, Rates.f23_98())
          range_01 = %Range{in: in_01, out: out_01, out_type: @out_type}

          {in_02, out_02} = @range_case.range_02
          in_02 = Timecode.with_frames!(in_02, Rates.f23_98())
          out_02 = Timecode.with_frames!(out_02, Rates.f23_98())
          range_02 = %Range{in: in_02, out: out_02, out_type: @out_type}

          assert Range.overlaps?(range_01, range_02) == @range_case.expected
        end

        if range_case.range_01 != range_case.range_02 do
          test "#{inspect(range_case.range_02)} | #{inspect(range_case.range_01)} | out #{out_type} | #{range_case.expected}" do
            {in_01, out_01} = @range_case.range_01
            in_01 = Timecode.with_frames!(in_01, Rates.f23_98())
            out_01 = Timecode.with_frames!(out_01, Rates.f23_98())
            range_01 = %Range{in: in_01, out: out_01, out_type: @out_type}

            {in_02, out_02} = @range_case.range_02
            in_02 = Timecode.with_frames!(in_02, Rates.f23_98())
            out_02 = Timecode.with_frames!(out_02, Rates.f23_98())
            range_02 = %Range{in: in_02, out: out_02, out_type: @out_type}

            assert Range.overlaps?(range_02, range_01) == @range_case.expected
          end
        end

        test "-#{inspect(range_case.range_01)} | -#{inspect(range_case.range_02)} | out #{out_type} | #{range_case.expected}" do
          {out_01, in_01} = @range_case.range_01
          in_01 = in_01 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
          out_01 = out_01 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
          range_01 = %Range{in: in_01, out: out_01, out_type: @out_type}

          {out_02, in_02} = @range_case.range_02
          in_02 = in_02 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
          out_02 = out_02 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
          range_02 = %Range{in: in_02, out: out_02, out_type: @out_type}

          assert Range.overlaps?(range_01, range_02) == @range_case.expected
        end

        if range_case.range_01 != range_case.range_02 do
          test "-#{inspect(range_case.range_02)} | -#{inspect(range_case.range_01)} | out #{out_type} | #{range_case.expected}" do
            {out_01, in_01} = @range_case.range_01
            in_01 = in_01 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
            out_01 = out_01 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
            range_01 = %Range{in: in_01, out: out_01, out_type: @out_type}

            {out_02, in_02} = @range_case.range_02
            in_02 = in_02 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
            out_02 = out_02 |> Timecode.with_frames!(Rates.f23_98()) |> Timecode.negate()
            range_02 = %Range{in: in_02, out: out_02, out_type: @out_type}

            assert Range.overlaps?(range_02, range_01) == @range_case.expected
          end
        end
      end
    end
  end
end
