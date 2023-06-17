defmodule Vtc.RangeTest do
  @moduledoc false
  use Vtc.Test.Support.TestCase

  alias Vtc.Framerate
  alias Vtc.Range
  alias Vtc.Rates
  alias Vtc.Timecode

  setup [:setup_test_case]

  @typedoc """
  Shorthand way to specify a {timecode_in, timecode_out} in a test case for a
  setup function to build the timecodes and ranges.

  Timecodes should be specified in strings and the setup will choose a framerate to
  apply.
  """
  @type range_shorthand() :: {String.t(), String.t()} | {String.t(), String.t(), Range.out_type()}

  describe "new/3" do
    test "successfully creates a new range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, tc_out)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :exclusive
    end

    test "successfully creates a new range with inclusive out" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, tc_out, out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :inclusive
    end

    test "successfully creates a zero-length range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, tc_out)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :exclusive
    end

    test "successfully creates a zero-length inclusive range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("00:59:59:23", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, tc_out, out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :inclusive
    end

    test "successfully creates a range with a `Frames` value as out_tc" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, "02:00:00:00")
      assert range.in == tc_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an explicitly :exclusive range with a `Frames` value as out_tc" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, "02:00:00:00", out_type: :exclusive)
      assert range.in == tc_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an :inclusive range with a `Frames` value as out_tc" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(tc_in, "02:00:00:00", out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == expected_out
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

    test "fails with timecode parse error for bad `Frames` string" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      assert {:error, %Timecode.ParseError{}} = Range.new(tc_in, "not a timecode")
    end
  end

  describe "new!/3" do
    test "successfully creates a new range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(tc_in, tc_out)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :exclusive
    end

    test "successfully creates a new range with inclusive out" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(tc_in, tc_out, out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :inclusive
    end

    test "successfully creates a zero-length range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      assert range = Range.new!(tc_in, tc_out)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :exclusive
    end

    test "successfully creates a zero-length inclusive range" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("00:59:59:23", Rates.f23_98())

      assert range = Range.new!(tc_in, tc_out, out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == tc_out
      assert range.out_type == :inclusive
    end

    test "successfully creates a range with a `Frames` value as out_tc" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(tc_in, "02:00:00:00")
      assert range.in == tc_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an explicitly :exclusive range with a `Frames` value as out_tc" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(tc_in, "02:00:00:00", out_type: :exclusive)
      assert range.in == tc_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an :inclusive range with a `Frames` value as out_tc" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(tc_in, "02:00:00:00", out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == expected_out
      assert range.out_type == :inclusive
    end

    test "raises when out is less than in" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("00:59:59:23", Rates.f23_98())

      error = assert_raise(ArgumentError, fn -> Range.new!(tc_in, tc_out) end)
      assert Exception.message(error) == "`tc_out` must be greater than or equal to `tc_in`"
    end

    test "raises when rates are not the same" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      tc_out = Timecode.with_frames!("02:00:00:00", Rates.f24())

      error = assert_raise(ArgumentError, fn -> Range.new!(tc_in, tc_out) end)
      assert Exception.message(error) == "`tc_in` and `tc_out` must have same `rate`"
    end

    test "raises with timecode parse error for bad `Frames` string" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      assert_raise Timecode.ParseError, fn -> Range.new!(tc_in, "not a timecode") end
    end
  end

  describe "with_duration/3" do
    test "successfully constructs implicit :exclusive range" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("00:30:00:00", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(start_tc, duration)
      assert range.in == start_tc
      assert range.out == Timecode.with_frames!("01:30:00:00", Rates.f23_98())
      assert range.out_type == :exclusive
    end

    test "successfully constructs with out_type: :exclusive" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("00:30:00:00", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(start_tc, duration, out_type: :exclusive)
      assert range.in == start_tc
      assert range.out == Timecode.with_frames!("01:30:00:00", Rates.f23_98())
      assert range.out_type == :exclusive
    end

    test "successfully constructs with out_type: :inclusive" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("00:30:00:00", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(start_tc, duration, out_type: :inclusive)
      assert range.in == start_tc
      assert range.out == Timecode.with_frames!("01:29:59:23", Rates.f23_98())
      assert range.out_type == :inclusive
    end

    test "successfully creates a range with a `Frames` value as out_tc" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(tc_in, "01:00:00:00")
      assert range.in == tc_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an explicitly :exclusive range with a `Frames` value as out_tc" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(tc_in, "01:00:00:00", out_type: :exclusive)
      assert range.in == tc_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an :inclusive range with a `Frames` value as out_tc" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Timecode.with_frames!("01:59:59:23", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(tc_in, "01:00:00:00", out_type: :inclusive)
      assert range.in == tc_in
      assert range.out == expected_out
      assert range.out_type == :inclusive
    end

    test "fails on different rates" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("00:30:00:00", Rates.f24())

      assert {:error, error} = Range.with_duration(start_tc, duration)
      assert Exception.message(error) == "`tc_in` and `duration` must have same `rate`"
    end

    test "fails on negative duration" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("-00:30:00:00", Rates.f23_98())

      assert {:error, error} = Range.with_duration(start_tc, duration)
      assert Exception.message(error) == "`duration` must be greater than `0`"
    end

    test "fails on negative duration when out_type: :inclusive" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("-00:30:00:00", Rates.f23_98())

      assert {:error, error} = Range.with_duration(start_tc, duration, out_type: :inclusive)
      assert Exception.message(error) == "`duration` must be greater than `0`"
    end

    test "fails with timecode parse error for bad `Frames` string" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      assert {:error, %Timecode.ParseError{}} = Range.with_duration(tc_in, "not a timecode")
    end
  end

  describe "#with_duration!/3" do
    test "successfully constructs implicit :exclusive range" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("00:30:00:00", Rates.f23_98())

      assert range = Range.with_duration!(start_tc, duration)
      assert range.in == start_tc
      assert range.out == Timecode.with_frames!("01:30:00:00", Rates.f23_98())
      assert range.out_type == :exclusive
    end

    test "successfully constructs with out_type: :exclusive" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("00:30:00:00", Rates.f23_98())

      assert range = Range.with_duration!(start_tc, duration, out_type: :exclusive)
      assert range.in == start_tc
      assert range.out == Timecode.with_frames!("01:30:00:00", Rates.f23_98())
      assert range.out_type == :exclusive
    end

    test "successfully constructs with out_type: :inclusive" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("00:30:00:00", Rates.f23_98())

      assert range = Range.with_duration!(start_tc, duration, out_type: :inclusive)
      assert range.in == start_tc
      assert range.out == Timecode.with_frames!("01:29:59:23", Rates.f23_98())
      assert range.out_type == :inclusive
    end

    test "raises on different rates" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("00:30:00:00", Rates.f24())

      error = assert_raise(ArgumentError, fn -> Range.with_duration!(start_tc, duration) end)
      assert Exception.message(error) == "`tc_in` and `duration` must have same `rate`"
    end

    test "raises on negative duration" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("-00:30:00:00", Rates.f23_98())

      error = assert_raise(ArgumentError, fn -> Range.with_duration!(start_tc, duration) end)
      assert Exception.message(error) == "`duration` must be greater than `0`"
    end

    test "raises on negative duration when out_type: :inclusive" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("-00:30:00:00", Rates.f23_98())

      error =
        assert_raise(ArgumentError, fn ->
          Range.with_duration!(start_tc, duration, out_type: :inclusive)
        end)

      assert Exception.message(error) == "`duration` must be greater than `0`"
    end

    test "raises with timecode parse error for bad `Frames` string" do
      tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      assert_raise Timecode.ParseError, fn -> Range.with_duration!(tc_in, "not a timecode") end
    end
  end

  describe "#with_inclusive_out/1" do
    test "successful alters :exclusive input" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :exclusive}
      expected_out = Timecode.with_frames!("01:59:59:023", Rates.f23_98())

      assert %{out: ^expected_out} = Range.with_inclusive_out(range)
    end

    test "no change with :inclusive input" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :inclusive}

      assert %{out: ^out_tc} = Range.with_inclusive_out(range)
    end

    test "backs up 0-length :exclusive duration" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :exclusive}
      expected_out = Timecode.with_frames!("00:59:59:023", Rates.f23_98())

      assert %{out: ^expected_out} = Range.with_inclusive_out(range)
    end
  end

  describe "#with_exclusive_out/1" do
    test "successful alters :inclusive input" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :inclusive}
      expected_out = Timecode.with_frames!("02:00:00:01", Rates.f23_98())

      assert %{out: ^expected_out} = Range.with_exclusive_out(range)
    end

    test "no change with :exclusive input" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :exclusive}

      assert %{out: ^out_tc} = Range.with_exclusive_out(range)
    end

    test "rolls forward up 0-length :inclusive duration" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :inclsuive}
      expected_out = Timecode.with_frames!("01:00:00:01", Rates.f23_98())

      assert %{out: ^expected_out} = Range.with_exclusive_out(range)
    end
  end

  describe "#duration/1" do
    test "correctly reports :exclusive duration" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("01:30:00:00", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :exclusive}
      expected = Timecode.with_frames!("00:30:00:00", Rates.f23_98())

      assert Range.duration(range) == expected
    end

    test "correctly reports 0-frame :exclusive duration" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :exclusive}
      expected = Timecode.with_frames!("00:00:00:00", Rates.f23_98())

      assert Range.duration(range) == expected
    end

    test "correctly reports 1-frame :exclusive duration" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("01:00:00:01", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :exclusive}
      expected = Timecode.with_frames!("00:00:00:01", Rates.f23_98())

      assert Range.duration(range) == expected
    end

    test "correctly reports :inclusive duration" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("01:30:00:00", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :inclusive}
      expected = Timecode.with_frames!("00:30:00:01", Rates.f23_98())

      assert Range.duration(range) == expected
    end

    test "correctly reports 0-frame :inclusive duration" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("00:59:59:23", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :inclusive}
      expected = Timecode.with_frames!("00:00:00:00", Rates.f23_98())

      assert Range.duration(range) == expected
    end

    test "correctly reports 1-frame :inclusive duration" do
      in_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      out_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      range = %Range{in: in_tc, out: out_tc, out_type: :inclusive}
      expected = Timecode.with_frames!("00:00:00:01", Rates.f23_98())

      assert Range.duration(range) == expected
    end
  end

  describe "#contains/2?" do
    setup [:setup_timecodes, :setup_ranges, :setup_negates]

    @describetag timecodes: [:timecode]
    @describetag ranges: [:range]

    test_cases = [
      %{
        name: "range.in < tc < range.out | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        timecode: "01:30:00:00",
        expected: true
      },
      %{
        name: "tc == range.in | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        timecode: "01:00:00:00",
        expected: true,
        expected_negative: false
      },
      %{
        name: "tc == range.out - 1 | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        timecode: "01:59:59:23",
        expected: true
      },
      %{
        name: "tc == range.in - 1 | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        timecode: "00:59:59:23",
        expected: false
      },
      %{
        name: "tc == range.out | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        timecode: "02:00:00:00",
        expected: false,
        expected_negative: true
      },
      %{
        name: "tc < range.in | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        timecode: "00:30:00:00",
        expected: false
      },
      %{
        name: "tc < range.in | sign flipped | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        timecode: "-01:30:00:00",
        expected: false
      },
      %{
        name: "tc > range.out | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        timecode: "02:30:00:00",
        expected: false
      },
      %{
        name: "range.in < tc < range.out | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        timecode: "01:30:00:00",
        expected: true
      },
      %{
        name: "tc == range.in | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        timecode: "01:00:00:00",
        expected: true
      },
      %{
        name: "tc == range.out - 1 | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        timecode: "01:59:59:23",
        expected: true
      },
      %{
        name: "tc == range.in - 1 | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        timecode: "00:59:59:23",
        expected: false
      },
      %{
        name: "tc == range.out | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        timecode: "02:00:00:00",
        expected: true
      },
      %{
        name: "tc == range.out + 1 | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        timecode: "02:00:00:01",
        expected: false
      },
      %{
        name: "tc < range.in | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        timecode: "00:30:00:00",
        expected: false
      },
      %{
        name: "tc < range.in | sign flipped | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        timecode: "-01:30:00:00",
        expected: false
      },
      %{
        name: "tc > range.out | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        timecode: "02:30:00:00",
        expected: false
      }
    ]

    for test_case <- test_cases do
      table_test test_case.name, test_case do
        %{timecode: timecode, range: range, test_case: %{expected: expected}} = test_case
        assert Range.contains?(range, timecode) == expected
      end

      name = "#{test_case.name} | negative"

      @tag negate: [:range]
      table_test name, test_case do
        %{timecode: timecode, range: range, test_case: test_case} = test_case

        expected =
          case test_case do
            %{expected_negative: expected} -> expected
            %{expected: expected} -> expected
          end

        timecode = Timecode.mult(timecode, -1)
        assert Range.contains?(range, timecode) == expected
      end
    end
  end

  describe "#overlaps?/2" do
    setup [:setup_ranges, :setup_negates]

    @describetag ranges: [:a, :b]

    test_cases = [
      %{
        name: "a.in == b.in and a.out == b.out",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in == b.in and a.out < b.out",
        a: {"01:00:00:00", "01:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in == b.in and a.out > b.out",
        a: {"01:00:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in < b.in and a.out == b.out",
        a: {"00:30:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in < b.in and a.out < b.out",
        a: {"00:30:00:00", "01:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in < b.in and a.out > b.out",
        a: {"00:30:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in > b.in and a.out == b.out",
        a: {"01:30:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in > b.in and a.out < b.out",
        a: {"01:15:00:00", "01:45:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in > b.in and a.out > b.out",
        a: {"01:30:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a < b",
        a: {"00:00:00:00", "00:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: false
      },
      %{
        name: "a > b",
        a: {"02:30:00:00", "03:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: false
      },
      %{
        name: "a.out & b.in at boundary",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"02:00:00:00", "03:00:00:00"},
        expected: false
      },
      %{
        name: "a.in & b.out at boundary",
        a: {"03:00:00:00", "04:00:00:00"},
        b: {"02:00:00:00", "03:00:00:00"},
        expected: false
      }
    ]

    for test_case <- test_cases do
      table_test "#{test_case.name} | :exclusive", test_case do
        %{a: a, b: b, test_case: %{expected: expected}} = test_case
        assert Range.overlaps?(a, b) == expected
      end

      @tag out_type: :inclusive
      table_test "#{test_case.name} | :inclusive", test_case do
        %{a: a, b: b, test_case: %{expected: expected}} = test_case

        a = Range.with_inclusive_out(a)
        b = Range.with_inclusive_out(b)

        assert Range.overlaps?(a, b) == expected
      end

      @tag negate: [:a, :b]
      table_test "#{test_case.name} | :exclusive | negative", test_case do
        %{a: a, b: b, test_case: %{expected: expected}} = test_case
        assert Range.overlaps?(a, b) == expected
      end

      @tag out_type: :inclusive
      @tag negate: [:a, :b]
      table_test "#{test_case.name} | :inclusive | negative", test_case do
        %{a: a, b: b, test_case: %{expected: expected}} = test_case

        a = Range.with_inclusive_out(a)
        b = Range.with_inclusive_out(b)

        assert Range.overlaps?(a, b) == expected
      end

      if test_case.a != test_case.b do
        table_test "#{test_case.name} | :exclusive | flipped", test_case do
          %{a: a, b: b, test_case: %{expected: expected}} = test_case
          assert Range.overlaps?(b, a) == expected
        end

        @tag out_type: :inclusive
        table_test "#{test_case.name} | :inclusive | flipped", test_case do
          %{a: a, b: b, test_case: %{expected: expected}} = test_case

          a = Range.with_inclusive_out(a)
          b = Range.with_inclusive_out(b)

          assert Range.overlaps?(b, a) == expected
        end

        @tag negate: [:a, :b]
        table_test "#{test_case.name} | :exclusive | flipped | negative", test_case do
          %{a: a, b: b, test_case: %{expected: expected}} = test_case
          assert Range.overlaps?(b, a) == expected
        end

        @tag out_type: :inclusive
        @tag negate: [:a, :b]
        table_test "#{test_case.name} | :inclusive | flipped | negative", test_case do
          %{a: a, b: b, test_case: %{expected: expected}} = test_case

          a = Range.with_inclusive_out(a)
          b = Range.with_inclusive_out(b)

          assert Range.overlaps?(b, a) == expected
        end
      end
    end
  end

  describe "intersection/2" do
    setup [:setup_ranges, :setup_inclusives, :setup_negates, :setup_overlap_expected]
    @describetag ranges: [:a, :b, :expected]

    test_cases = [
      %{
        name: "a.in == b.in and a.out == b.out",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "02:00:00:00"}
      },
      %{
        name: "a.in == b.in and a.out < b.out",
        a: {"01:00:00:00", "01:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "01:30:00:00"}
      },
      %{
        name: "a.in == b.in and a.out > b.out",
        a: {"01:00:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "02:00:00:00"}
      },
      %{
        name: "a.in < b.in and a.out == b.out",
        a: {"00:30:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "02:00:00:00"}
      },
      %{
        name: "a.in < b.in and a.out < b.out",
        a: {"00:30:00:00", "01:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "01:30:00:00"}
      },
      %{
        name: "a.in < b.in and a.out > b.out",
        a: {"00:30:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "02:00:00:00"}
      },
      %{
        name: "a.in > b.in and a.out == b.out",
        a: {"01:30:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:30:00:00", "02:00:00:00"}
      },
      %{
        name: "a.in > b.in and a.out < b.out",
        a: {"01:15:00:00", "01:45:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:15:00:00", "01:45:00:00"}
      },
      %{
        name: "a.in > b.in and a.out > b.out",
        a: {"01:30:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:30:00:00", "02:00:00:00"}
      },
      %{
        name: "a < b",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"03:00:00:00", "04:00:00:00"},
        expected: {:error, :none}
      },
      %{
        name: "a > b",
        a: {"03:00:00:00", "04:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {:error, :none}
      },
      %{
        name: "a.out & b.in at boundary",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"02:00:00:00", "03:00:00:00"},
        expected: {:error, :none}
      },
      %{
        name: "a.in & b.out at boundary",
        a: {"03:00:00:00", "04:00:00:00"},
        b: {"02:00:00:00", "03:00:00:00"},
        expected: {:error, :none}
      }
    ]

    for test_case <- test_cases do
      table_test "#{test_case.name} | :exclusive", test_case do
        %{a: a, b: b, expected: expected} = test_case
        assert Range.intersection(a, b) == expected
      end

      @tag negate: [:a, :b, :expected]
      table_test "#{test_case.name} | :exclusive | negative", test_case do
        %{a: a, b: b, expected: expected} = test_case
        assert Range.intersection(a, b) == expected
      end

      @tag inclusive: [:a, :b, :expected]
      table_test "#{test_case.name} | :inclusive", test_case do
        %{a: a, b: b, expected: expected} = test_case
        assert Range.intersection(a, b) == expected
      end

      @tag inclusive: [:a, :b, :expected]
      @tag negate: [:a, :b, :expected]
      table_test "#{test_case.name} | :inclusive | negative", test_case do
        %{a: a, b: b, expected: expected} = test_case
        assert Range.intersection(a, b) == expected
      end

      if test_case.a != test_case.b do
        table_test "#{test_case.name} | :exclusive | flipped", test_case do
          %{a: a, b: b, expected: expected} = test_case
          assert Range.intersection(b, a) == expected
        end

        @tag negate: [:a, :b, :expected]
        table_test "#{test_case.name} | :exclusive | negative | flipped", test_case do
          %{a: a, b: b, expected: expected} = test_case
          assert Range.intersection(b, a) == expected
        end

        @tag inclusive: [:a, :b, :expected]
        table_test "#{test_case.name} | :inclusive | flipped", test_case do
          %{a: a, b: b, expected: expected} = test_case
          assert Range.intersection(b, a) == expected
        end

        @tag inclusive: [:a, :b, :expected]
        @tag negate: [:a, :b, :expected]
        table_test "#{test_case.name} | :inclusive | negative | flipped", test_case do
          %{a: a, b: b, expected: expected} = test_case
          assert Range.intersection(b, a) == expected
        end
      end
    end

    test "inherets a's rate in mixed rate operations" do
      a = setup_range({"01:00:00:00", "02:00:00:00"}, Rates.f23_98())
      b = setup_range({"01:00:00:00", "02:00:00:00"}, Rates.f47_95())
      expected = setup_range({"01:00:00:00", "02:00:00:00"}, Rates.f23_98())

      assert {:ok, result} = Range.intersection(a, b)
      assert result == expected
    end

    test "inherets a's out_type in mixed type operations" do
      a = {"01:00:00:00", "02:00:00:00"} |> setup_range() |> Range.with_inclusive_out()
      b = setup_range({"01:00:00:00", "02:00:00:00"})
      expected = {"01:00:00:00", "02:00:00:00"} |> setup_range() |> Range.with_inclusive_out()

      assert {:ok, result} = Range.intersection(a, b)
      assert result == expected
    end

    test "successfully returns mixed rate" do
      a = setup_range({"01:00:00:03", "01:59:59:47"}, Rates.f47_95())
      b = setup_range({"01:00:00:01", "01:59:59:23"}, Rates.f23_98())
      expected = setup_range({"01:00:00:03", "01:59:59:46"}, Rates.f47_95())

      assert {:ok, result} = Range.intersection(a, b)
      assert result == expected
    end
  end

  describe "#intersection!/2" do
    test "returns bare range on success" do
      a = setup_range({"01:00:00:00", "02:00:00:00"})
      b = setup_range({"01:00:00:00", "02:00:00:00"})

      expected = setup_range({"01:00:00:00", "02:00:00:00"})
      assert Range.intersection!(a, b) == expected
    end

    test "returns zero-length range when no overlap" do
      a = setup_range({"01:00:00:00", "02:00:00:00"})
      b = setup_range({"03:00:00:00", "04:00:00:00"})

      expected = setup_range({"00:00:00:00", "00:00:00:00"})
      assert Range.intersection!(a, b) == expected
    end

    test "zero-length inherets a's rate in mixed rate operations" do
      a = setup_range({"01:00:00:00", "02:00:00:00"}, Rates.f47_95())
      b = setup_range({"03:00:00:00", "04:00:00:00"}, Rates.f23_98())

      expected = setup_range({"00:00:00:00", "00:00:00:00"}, Rates.f47_95())
      assert Range.intersection!(a, b) == expected
    end

    test "zero-length inherets a's out_type" do
      a = {"01:00:00:00", "02:00:00:00"} |> setup_range() |> Range.with_inclusive_out()
      b = setup_range({"03:00:00:00", "04:00:00:00"})

      expected = {"00:00:00:00", "00:00:00:00"} |> setup_range() |> Range.with_inclusive_out()
      assert Range.intersection!(a, b) == expected
    end
  end

  describe "separation/2" do
    setup [:setup_ranges, :setup_inclusives, :setup_negates, :setup_overlap_expected]
    @describetag ranges: [:a, :b, :expected]

    test_cases = [
      %{
        name: "a < b",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"03:00:00:00", "04:00:00:00"},
        expected: {"02:00:00:00", "03:00:00:00"}
      },
      %{
        name: "error on overlap",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {:error, :none}
      }
    ]

    for test_case <- test_cases do
      table_test "#{test_case.name} | :exclusive", test_case do
        %{a: a, b: b, expected: expected} = test_case
        assert Range.separation(a, b) == expected
      end

      @tag negate: [:a, :b, :expected]
      table_test "#{test_case.name} | :exclusive | negative", test_case do
        %{a: a, b: b, expected: expected} = test_case
        assert Range.separation(a, b) == expected
      end

      @tag inclusive: [:a, :b, :expected]
      table_test "#{test_case.name} | :inclusive", test_case do
        %{a: a, b: b, expected: expected} = test_case
        assert Range.separation(a, b) == expected
      end

      @tag inclusive: [:a, :b, :expected]
      @tag negate: [:a, :b, :expected]
      table_test "#{test_case.name} | :inclusive | negative", test_case do
        %{a: a, b: b, expected: expected} = test_case
        assert Range.separation(a, b) == expected
      end

      if test_case.a != test_case.b do
        table_test "#{test_case.name} | :exclusive  | flipped", test_case do
          %{a: a, b: b, expected: expected} = test_case
          assert Range.separation(b, a) == expected
        end

        @tag negate: [:a, :b, :expected]
        table_test "#{test_case.name} | :exclusive | flipped | negative", test_case do
          %{a: a, b: b, expected: expected} = test_case
          assert Range.separation(b, a) == expected
        end

        @tag inclusive: [:a, :b, :expected]
        table_test "#{test_case.name} | :inclusive  | flipped", test_case do
          %{a: a, b: b, expected: expected} = test_case
          assert Range.separation(b, a) == expected
        end

        @tag inclusive: [:a, :b, :expected]
        @tag negate: [:a, :b, :expected]
        table_test "#{test_case.name} | :inclusive  | flipped | negative", test_case do
          %{a: a, b: b, expected: expected} = test_case
          assert Range.separation(b, a) == expected
        end
      end
    end

    test "inherets a's rate in mixed rate operations" do
      a = setup_range({"01:00:00:00", "02:00:00:00"}, Rates.f23_98())
      b = setup_range({"03:00:00:00", "04:00:00:00"}, Rates.f47_95())
      expected = setup_range({"02:00:00:00", "03:00:00:00"}, Rates.f23_98())

      assert {:ok, result} = Range.separation(a, b)
      assert result == expected
    end

    test "inherets a's out_type in mixed type operations" do
      a = {"01:00:00:00", "02:00:00:00"} |> setup_range() |> Range.with_inclusive_out()
      b = setup_range({"03:00:00:00", "04:00:00:00"})
      expected = {"02:00:00:00", "03:00:00:00"} |> setup_range() |> Range.with_inclusive_out()

      assert {:ok, result} = Range.separation(a, b)
      assert result == expected
    end

    test "successfully returns mixed rate" do
      a = setup_range({"01:00:00:03", "01:59:59:47"}, Rates.f47_95())
      b = setup_range({"03:00:00:23", "03:00:00:00"}, Rates.f23_98())
      expected = setup_range({"01:59:59:47", "03:00:00:46"}, Rates.f47_95())

      assert {:ok, result} = Range.separation(a, b)
      assert result == expected
    end
  end

  describe "#separation!/2" do
    test "returns bare range on success" do
      a = setup_range({"01:00:00:00", "02:00:00:00"})
      b = setup_range({"03:00:00:00", "04:00:00:00"})

      expected = setup_range({"02:00:00:00", "03:00:00:00"})
      assert Range.separation!(a, b) == expected
    end

    test "returns zero-length range when overlap" do
      a = setup_range({"01:00:00:00", "02:00:00:00"})
      b = setup_range({"01:00:00:00", "02:00:00:00"})

      expected = setup_range({"00:00:00:00", "00:00:00:00"})
      assert Range.separation!(a, b) == expected
    end

    test "zero-length inherets a's rate in mixed rate operations" do
      a = setup_range({"01:00:00:00", "02:00:00:00"}, Rates.f47_95())
      b = setup_range({"01:00:00:00", "02:00:00:00"}, Rates.f23_98())

      expected = setup_range({"00:00:00:00", "00:00:00:00"}, Rates.f47_95())
      assert Range.separation!(a, b) == expected
    end

    test "zero-length inherets a's out_type" do
      a = {"01:00:00:00", "02:00:00:00"} |> setup_range() |> Range.with_inclusive_out()
      b = setup_range({"01:00:00:00", "02:00:00:00"})

      expected = {"00:00:00:00", "00:00:00:00"} |> setup_range() |> Range.with_inclusive_out()
      assert Range.separation!(a, b) == expected
    end
  end

  describe "String.Chars.to_string/1" do
    test "renders expected for :exclusive" do
      range = setup_range({"01:00:00:00", "02:00:00:00"})

      assert String.Chars.to_string(range) ==
               "<01:00:00:00 - 02:00:00:00 :exclusive <23.98 NTSC>>"
    end

    test "renders expected for :inclusive" do
      range = {"01:00:00:00", "02:00:00:00"} |> setup_range() |> Range.with_inclusive_out()

      assert String.Chars.to_string(range) ==
               "<01:00:00:00 - 01:59:59:23 :inclusive <23.98 NTSC>>"
    end
  end

  describe "Inspect.inspect/2" do
    test "renders expected for :exclusive" do
      range = setup_range({"01:00:00:00", "02:00:00:00"})

      assert Inspect.inspect(range, Inspect.Opts.new([])) ==
               "<01:00:00:00 - 02:00:00:00 :exclusive <23.98 NTSC>>"
    end

    test "renders expected for :inclusive" do
      range = {"01:00:00:00", "02:00:00:00"} |> setup_range() |> Range.with_inclusive_out()

      assert Inspect.inspect(range, Inspect.Opts.new([])) ==
               "<01:00:00:00 - 01:59:59:23 :inclusive <23.98 NTSC>>"
    end
  end

  # Turns specified test case range shorthands into full blown ranges.
  @spec setup_ranges(%{optional(:ranges) => [Map.key()]}) :: Keyword.t()
  defp setup_ranges(%{ranges: attrs} = test_case) do
    test_case
    |> Map.take(attrs)
    |> Enum.into([])
    |> Enum.map(fn {name, values} -> {name, setup_range(values)} end)
  end

  defp setup_ranges(test_case), do: test_case

  # Allow `:none` for `intersection/2` and `separation/2` function tests.
  @spec setup_range(range_shorthand() | {:error, any()}, Framerate.t()) ::
          Range.t() | {:error, any()}
  defp setup_range(values, rate \\ Rates.f23_98())

  defp setup_range({in_tc, out_tc, out_type}, rate) do
    in_tc = Timecode.with_frames!(in_tc, rate)
    out_tc = Timecode.with_frames!(out_tc, rate)

    %Range{in: in_tc, out: out_tc, out_type: out_type}
  end

  defp setup_range({in_tc, out_tc}, rate) when is_binary(in_tc) and is_binary(out_tc) do
    in_tc = Timecode.with_frames!(in_tc, rate)
    out_tc = Timecode.with_frames!(out_tc, rate)
    %Range{in: in_tc, out: out_tc, out_type: :exclusive}
  end

  defp setup_range(value, _), do: value

  # Males secified ranges built by setup_ranges out-inclusive.
  @spec setup_inclusives(%{optional(:inclusive) => [Map.key()]}) :: Keyword.t()
  defp setup_inclusives(%{inclusive: attrs} = test_case) do
    test_case
    |> Map.take(attrs)
    |> Enum.into([])
    |> Enum.map(fn {name, values} -> {name, setup_inclusive(values)} end)
  end

  defp setup_inclusives(test_case), do: test_case

  @spec setup_inclusive(Range.t() | {:error, any()}) :: Range.t() | {:error, any()}
  defp setup_inclusive(%Range{} = range), do: Range.with_inclusive_out(range)
  defp setup_inclusive(value), do: value

  @spec setup_overlap_expected(%{optional(:expected) => Range.t() | {:error, any()}}) :: map()
  defp setup_overlap_expected(%{expected: %Range{} = expected}), do: [expected: {:ok, expected}]

  defp setup_overlap_expected(test_case), do: test_case
end
