defmodule Vtc.Framestamp.RangeTest do
  @moduledoc false
  use Vtc.Test.Support.TestCase

  alias Vtc.Framestamp
  alias Vtc.Framestamp.Range
  alias Vtc.Rates
  alias Vtc.Test.Support.CommonTables

  describe "new/3" do
    test "successfully creates a new range" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(stamp_in, stamp_out)
      assert range.in == stamp_in
      assert range.out == stamp_out
      assert range.out_type == :exclusive
    end

    test "successfully creates a new range with inclusive out" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(stamp_in, stamp_out, out_type: :inclusive)
      assert range.in == stamp_in
      assert range.out == stamp_out
      assert range.out_type == :inclusive
    end

    test "successfully creates a zero-length range" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(stamp_in, stamp_out)
      assert range.in == stamp_in
      assert range.out == stamp_out
      assert range.out_type == :exclusive
    end

    test "successfully creates a zero-length inclusive range" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("00:59:59:23", Rates.f23_98())

      assert {:ok, range} = Range.new(stamp_in, stamp_out, out_type: :inclusive)
      assert range.in == stamp_in
      assert range.out == stamp_out
      assert range.out_type == :inclusive
    end

    test "successfully creates a range with a `Frames` value as out_stamp" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(stamp_in, "02:00:00:00")
      assert range.in == stamp_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an explicitly :exclusive range with a `Frames` value as out_stamp" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(stamp_in, "02:00:00:00", out_type: :exclusive)
      assert range.in == stamp_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an :inclusive range with a `Frames` value as out_stamp" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.new(stamp_in, "02:00:00:00", out_type: :inclusive)
      assert range.in == stamp_in
      assert range.out == expected_out
      assert range.out_type == :inclusive
    end

    test "fails when out is less than in" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("00:59:59:23", Rates.f23_98())

      assert {:error, error} = Range.new(stamp_in, stamp_out)
      assert Exception.message(error) == "`stamp_out` must be greater than or equal to `stamp_in`"
    end

    test "fails when rates are not the same" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("02:00:00:00", Rates.f24())

      assert {:error, error} = Range.new(stamp_in, stamp_out)
      assert Exception.message(error) == "`stamp_in` and `stamp_out` must have same `rate`"
    end

    test "fails with framestamp parse error for bad `Frames` string" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      assert {:error, %Framestamp.ParseError{}} = Range.new(stamp_in, "not a timecode")
    end
  end

  describe "new!/3" do
    test "successfully creates a new range" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(stamp_in, stamp_out)
      assert range.in == stamp_in
      assert range.out == stamp_out
      assert range.out_type == :exclusive
    end

    test "successfully creates a new range with inclusive out" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(stamp_in, stamp_out, out_type: :inclusive)
      assert range.in == stamp_in
      assert range.out == stamp_out
      assert range.out_type == :inclusive
    end

    test "successfully creates a zero-length range" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      assert range = Range.new!(stamp_in, stamp_out)
      assert range.in == stamp_in
      assert range.out == stamp_out
      assert range.out_type == :exclusive
    end

    test "successfully creates a zero-length inclusive range" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("00:59:59:23", Rates.f23_98())

      assert range = Range.new!(stamp_in, stamp_out, out_type: :inclusive)
      assert range.in == stamp_in
      assert range.out == stamp_out
      assert range.out_type == :inclusive
    end

    test "successfully creates a range with a `Frames` value as out_stamp" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(stamp_in, "02:00:00:00")
      assert range.in == stamp_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an explicitly :exclusive range with a `Frames` value as out_stamp" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(stamp_in, "02:00:00:00", out_type: :exclusive)
      assert range.in == stamp_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an :inclusive range with a `Frames` value as out_stamp" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert range = Range.new!(stamp_in, "02:00:00:00", out_type: :inclusive)
      assert range.in == stamp_in
      assert range.out == expected_out
      assert range.out_type == :inclusive
    end

    test "raises when out is less than in" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("00:59:59:23", Rates.f23_98())

      error = assert_raise(ArgumentError, fn -> Range.new!(stamp_in, stamp_out) end)
      assert Exception.message(error) == "`stamp_out` must be greater than or equal to `stamp_in`"
    end

    test "raises when rates are not the same" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_out = Framestamp.with_frames!("02:00:00:00", Rates.f24())

      error = assert_raise(ArgumentError, fn -> Range.new!(stamp_in, stamp_out) end)
      assert Exception.message(error) == "`stamp_in` and `stamp_out` must have same `rate`"
    end

    test "raises with framestamp parse error for bad `Frames` string" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      assert_raise Framestamp.ParseError, fn -> Range.new!(stamp_in, "not a timecode") end
    end
  end

  describe "with_duration/3" do
    test "successfully constructs implicit :exclusive range" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(start_stamp, duration)
      assert range.in == start_stamp
      assert range.out == Framestamp.with_frames!("01:30:00:00", Rates.f23_98())
      assert range.out_type == :exclusive
    end

    test "successfully constructs with out_type: :exclusive" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(start_stamp, duration, out_type: :exclusive)
      assert range.in == start_stamp
      assert range.out == Framestamp.with_frames!("01:30:00:00", Rates.f23_98())
      assert range.out_type == :exclusive
    end

    test "successfully constructs with out_type: :inclusive" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(start_stamp, duration, out_type: :inclusive)
      assert range.in == start_stamp
      assert range.out == Framestamp.with_frames!("01:29:59:23", Rates.f23_98())
      assert range.out_type == :inclusive
    end

    test "successfully creates a range with a `Frames` value as out_stamp" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(stamp_in, "01:00:00:00")
      assert range.in == stamp_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an explicitly :exclusive range with a `Frames` value as out_stamp" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(stamp_in, "01:00:00:00", out_type: :exclusive)
      assert range.in == stamp_in
      assert range.out == expected_out
      assert range.out_type == :exclusive
    end

    test "successfully creates an :inclusive range with a `Frames` value as out_stamp" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      expected_out = Framestamp.with_frames!("01:59:59:23", Rates.f23_98())

      assert {:ok, range} = Range.with_duration(stamp_in, "01:00:00:00", out_type: :inclusive)
      assert range.in == stamp_in
      assert range.out == expected_out
      assert range.out_type == :inclusive
    end

    test "fails on different rates" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("00:30:00:00", Rates.f24())

      assert {:error, error} = Range.with_duration(start_stamp, duration)
      assert Exception.message(error) == "`stamp_in` and `duration` must have same `rate`"
    end

    test "fails on negative duration" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("-00:30:00:00", Rates.f23_98())

      assert {:error, error} = Range.with_duration(start_stamp, duration)
      assert Exception.message(error) == "`duration` must be greater than `0`"
    end

    test "fails on negative duration when out_type: :inclusive" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("-00:30:00:00", Rates.f23_98())

      assert {:error, error} = Range.with_duration(start_stamp, duration, out_type: :inclusive)
      assert Exception.message(error) == "`duration` must be greater than `0`"
    end

    test "fails with framestamp parse error for bad `Frames` string" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      assert {:error, %Framestamp.ParseError{}} = Range.with_duration(stamp_in, "not a timecode")
    end
  end

  describe "#with_duration!/3" do
    test "successfully constructs implicit :exclusive range" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())

      assert range = Range.with_duration!(start_stamp, duration)
      assert range.in == start_stamp
      assert range.out == Framestamp.with_frames!("01:30:00:00", Rates.f23_98())
      assert range.out_type == :exclusive
    end

    test "successfully constructs with out_type: :exclusive" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())

      assert range = Range.with_duration!(start_stamp, duration, out_type: :exclusive)
      assert range.in == start_stamp
      assert range.out == Framestamp.with_frames!("01:30:00:00", Rates.f23_98())
      assert range.out_type == :exclusive
    end

    test "successfully constructs with out_type: :inclusive" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())

      assert range = Range.with_duration!(start_stamp, duration, out_type: :inclusive)
      assert range.in == start_stamp
      assert range.out == Framestamp.with_frames!("01:29:59:23", Rates.f23_98())
      assert range.out_type == :inclusive
    end

    test "raises on different rates" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("00:30:00:00", Rates.f24())

      error = assert_raise(ArgumentError, fn -> Range.with_duration!(start_stamp, duration) end)
      assert Exception.message(error) == "`stamp_in` and `duration` must have same `rate`"
    end

    test "raises on negative duration" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("-00:30:00:00", Rates.f23_98())

      error = assert_raise(ArgumentError, fn -> Range.with_duration!(start_stamp, duration) end)
      assert Exception.message(error) == "`duration` must be greater than `0`"
    end

    test "raises on negative duration when out_type: :inclusive" do
      start_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Framestamp.with_frames!("-00:30:00:00", Rates.f23_98())

      error =
        assert_raise(ArgumentError, fn ->
          Range.with_duration!(start_stamp, duration, out_type: :inclusive)
        end)

      assert Exception.message(error) == "`duration` must be greater than `0`"
    end

    test "raises with framestamp parse error for bad `Frames` string" do
      stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      assert_raise Framestamp.ParseError, fn -> Range.with_duration!(stamp_in, "not a timecode") end
    end
  end

  describe "#with_inclusive_out/1" do
    test "successful alters :exclusive input" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :exclusive}
      expected_out = Framestamp.with_frames!("01:59:59:023", Rates.f23_98())

      assert %{out: ^expected_out} = Range.with_inclusive_out(range)
    end

    test "no change with :inclusive input" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :inclusive}

      assert %{out: ^out_stamp} = Range.with_inclusive_out(range)
    end

    test "backs up 0-length :exclusive duration" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :exclusive}
      expected_out = Framestamp.with_frames!("00:59:59:023", Rates.f23_98())

      assert %{out: ^expected_out} = Range.with_inclusive_out(range)
    end
  end

  describe "#with_exclusive_out/1" do
    test "successful alters :inclusive input" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :inclusive}
      expected_out = Framestamp.with_frames!("02:00:00:01", Rates.f23_98())

      assert %{out: ^expected_out} = Range.with_exclusive_out(range)
    end

    test "no change with :exclusive input" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :exclusive}

      assert %{out: ^out_stamp} = Range.with_exclusive_out(range)
    end

    test "rolls forward up 0-length :inclusive duration" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :inclusive}
      expected_out = Framestamp.with_frames!("01:00:00:01", Rates.f23_98())

      assert %{out: ^expected_out} = Range.with_exclusive_out(range)
    end
  end

  describe "#duration/1" do
    test "correctly reports :exclusive duration" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("01:30:00:00", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :exclusive}
      expected = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())

      assert Range.duration(range) == expected
    end

    test "correctly reports 0-frame :exclusive duration" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :exclusive}
      expected = Framestamp.with_frames!("00:00:00:00", Rates.f23_98())

      assert Range.duration(range) == expected
    end

    test "correctly reports 1-frame :exclusive duration" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("01:00:00:01", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :exclusive}
      expected = Framestamp.with_frames!("00:00:00:01", Rates.f23_98())

      assert Range.duration(range) == expected
    end

    test "correctly reports :inclusive duration" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("01:30:00:00", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :inclusive}
      expected = Framestamp.with_frames!("00:30:00:01", Rates.f23_98())

      assert Range.duration(range) == expected
    end

    test "correctly reports 0-frame :inclusive duration" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("00:59:59:23", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :inclusive}
      expected = Framestamp.with_frames!("00:00:00:00", Rates.f23_98())

      assert Range.duration(range) == expected
    end

    test "correctly reports 1-frame :inclusive duration" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      range = %Range{in: in_stamp, out: out_stamp, out_type: :inclusive}
      expected = Framestamp.with_frames!("00:00:00:01", Rates.f23_98())

      assert Range.duration(range) == expected
    end
  end

  describe "#contains/2?" do
    setup context, do: TestCase.setup_framestamps(context)
    setup context, do: TestCase.setup_ranges(context)
    setup context, do: TestCase.setup_negates(context)

    @describetag framestamps: [:framestamp]
    @describetag ranges: [:range]

    table_test test_case.name, CommonTables.range_contains(), test_case do
      %{framestamp: framestamp, range: range, expected: expected} = test_case
      assert Range.contains?(range, framestamp) == expected
    end

    @tag negate: [:range, :framestamp]
    table_test "<%= name %> | negative", CommonTables.range_contains(), test_case do
      %{framestamp: framestamp, range: range, test_case: test_case} = test_case

      expected =
        case test_case do
          %{expected_negative: expected} -> expected
          %{expected: expected} -> expected
        end

      assert Range.contains?(range, framestamp) == expected
    end
  end

  describe "#overlaps?/2" do
    setup context, do: TestCase.setup_ranges(context)
    setup context, do: TestCase.setup_negates(context)

    @describetag ranges: [:a, :b]

    table_test "<%= name %> | :exclusive", CommonTables.range_overlaps(), test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.overlaps?(a, b) == expected
    end

    @tag out_type: :inclusive
    table_test "<%= name %> | :inclusive", CommonTables.range_overlaps(), test_case do
      %{a: a, b: b, expected: expected} = test_case

      a = Range.with_inclusive_out(a)
      b = Range.with_inclusive_out(b)

      assert Range.overlaps?(a, b) == expected
    end

    @tag negate: [:a, :b]
    table_test "<%= name %> | :exclusive | negative", CommonTables.range_overlaps(), test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.overlaps?(a, b) == expected
    end

    @tag out_type: :inclusive
    @tag negate: [:a, :b]
    table_test "<%= name %> | :inclusive | negative", CommonTables.range_overlaps(), test_case do
      %{a: a, b: b, expected: expected} = test_case

      a = Range.with_inclusive_out(a)
      b = Range.with_inclusive_out(b)

      assert Range.overlaps?(a, b) == expected
    end

    table_test "<%= name %> | :exclusive | flipped", CommonTables.range_overlaps(), test_case,
      if: test_case.a != test_case.b do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.overlaps?(b, a) == expected
    end

    @tag out_type: :inclusive
    table_test "<%= name %> | :inclusive | flipped", CommonTables.range_overlaps(), test_case,
      if: test_case.a != test_case.b do
      %{a: a, b: b, expected: expected} = test_case

      a = Range.with_inclusive_out(a)
      b = Range.with_inclusive_out(b)

      assert Range.overlaps?(b, a) == expected
    end

    @tag negate: [:a, :b]
    table_test "<%= name %> | :exclusive | flipped | negative", CommonTables.range_overlaps(), test_case,
      if: test_case.a != test_case.b do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.overlaps?(b, a) == expected
    end

    @tag out_type: :inclusive
    @tag negate: [:a, :b]
    table_test "<%= name %> | :inclusive | flipped | negative", CommonTables.range_overlaps(), test_case,
      if: test_case.a != test_case.b do
      %{a: a, b: b, expected: expected} = test_case

      a = Range.with_inclusive_out(a)
      b = Range.with_inclusive_out(b)

      assert Range.overlaps?(b, a) == expected
    end
  end

  describe "intersection/2" do
    setup context, do: TestCase.setup_ranges(context)
    setup [:setup_inclusives]
    setup context, do: TestCase.setup_negates(context)
    setup [:setup_overlap_expected]

    @describetag ranges: [:a, :b, :expected]

    table_test "<%= name %> | :exclusive", CommonTables.range_intersection(), test_case,
      if: not (test_case.name =~ "mixed rate") do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(a, b) == expected
    end

    table_test "<%= name %> | :exclusive | inherit left rate", CommonTables.range_intersection(), test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(a, b, inherit_rate: :left) == expected
    end

    table_test "<%= name %> | :exclusive | inherit right rate", CommonTables.range_intersection(), test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(b, a, inherit_rate: :right) == expected
    end

    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | :exclusive | negative", CommonTables.range_intersection(), test_case,
      if: not (test_case.name =~ "mixed rate") do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(a, b) == expected
    end

    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | :exclusive | negative | inherit left rate", CommonTables.range_intersection(), test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(a, b, inherit_rate: :left) == expected
    end

    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | :exclusive | negative | inherit right rate", CommonTables.range_intersection(), test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(b, a, inherit_rate: :right) == expected
    end

    @tag inclusive: [:a, :b, :expected]
    table_test "<%= name %> | :inclusive", CommonTables.range_intersection(), test_case,
      if: not (test_case.name =~ "mixed rate") do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(a, b) == expected
    end

    @tag inclusive: [:a, :b, :expected]
    table_test "<%= name %> | :inclusive | inherit left rate", CommonTables.range_intersection(), test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(a, b, inherit_rate: :left) == expected
    end

    @tag inclusive: [:a, :b, :expected]
    table_test "<%= name %> | :inclusive | inherit right rate", CommonTables.range_intersection(), test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(b, a, inherit_rate: :right) == expected
    end

    @tag inclusive: [:a, :b, :expected]
    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | :inclusive | negative", CommonTables.range_intersection(), test_case,
      if: not (test_case.name =~ "mixed rate") do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(a, b) == expected
    end

    table_test "<%= name %> | :exclusive | flipped", CommonTables.range_intersection(), test_case,
      if: test_case.a != test_case.b and not (test_case.name =~ "mixed rate") do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(b, a) == expected
    end

    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | :exclusive | negative | flipped", CommonTables.range_intersection(), test_case,
      if: test_case.a != test_case.b and not (test_case.name =~ "mixed rate") do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(b, a) == expected
    end

    @tag inclusive: [:a, :b, :expected]
    table_test "<%= name %> | :inclusive | flipped", CommonTables.range_intersection(), test_case,
      if: test_case.a != test_case.b and not (test_case.name =~ "mixed rate") do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(b, a) == expected
    end

    @tag inclusive: [:a, :b, :expected]
    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | :inclusive | negative | flipped", CommonTables.range_intersection(), test_case,
      if: test_case.a != test_case.b and not (test_case.name =~ "mixed rate") do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.intersection(b, a) == expected
    end

    test "inherits out_type in mixed type operations | :left" do
      a = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()
      b = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      expected = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()

      assert {:ok, result} = Range.intersection(a, b, inherit_rate: :left, inherit_out_type: :left)
      assert result == expected
    end

    test "inherits out_type in mixed type operations | :right" do
      a = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()
      b = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      expected = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})

      assert {:ok, result} = Range.intersection(a, b, inherit_rate: :left, inherit_out_type: :right)
      assert result == expected
    end

    test "errors on mixed rate" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = TestCase.setup_range({"01:00:00:00", "04:00:00:00", Rates.f47_95()})

      error = assert_raise Framestamp.MixedRateArithmeticError, fn -> Range.intersection(a, b) end
      assert error.func_name == :intersection
      assert error.left_rate == Rates.f23_98()
      assert error.right_rate == Rates.f47_95()
    end

    test "errors on mixed out type" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = {"03:00:00:00", "04:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()

      error = assert_raise Framestamp.Range.MixedOutTypeArithmeticError, fn -> Range.intersection(a, b) end
      assert error.func_name == :intersection
      assert error.left_out_type == :exclusive
      assert error.right_out_type == :inclusive
    end
  end

  describe "#intersection!/2" do
    test "returns bare range on success" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})

      expected = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      assert Range.intersection!(a, b, inherit_rate: :left, inherit_out_type: :left) == expected
    end

    test "returns zero-length range when no overlap" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00"})

      expected = TestCase.setup_range({"00:00:00:00", "00:00:00:00"})
      assert Range.intersection!(a, b) == expected
    end

    test "zero-length inherits rate in mixed rate operations | :left" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00", Rates.f47_95()})
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00", Rates.f23_98()})

      expected = TestCase.setup_range({"00:00:00:00", "00:00:00:00", Rates.f47_95()})
      assert Range.intersection!(a, b, inherit_rate: :left, inherit_out_type: :left) == expected
    end

    test "zero-length inherits rate in mixed rate operations | :right" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00", Rates.f47_95()})
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00", Rates.f23_98()})

      expected = TestCase.setup_range({"00:00:00:00", "00:00:00:00", Rates.f23_98()})
      assert Range.intersection!(a, b, inherit_rate: :right, inherit_out_type: :right) == expected
    end

    test "zero-length inherits out_type | :left" do
      a = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00"})

      expected = {"00:00:00:00", "00:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()
      assert Range.intersection!(a, b, inherit_rate: :left, inherit_out_type: :left) == expected
    end

    test "zero-length inherits out_type | :right" do
      a = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00"})

      expected = TestCase.setup_range({"00:00:00:00", "00:00:00:00"})
      assert Range.intersection!(a, b, inherit_rate: :right, inherit_out_type: :right) == expected
    end

    test "errors on mixed rate" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = TestCase.setup_range({"01:00:00:00", "04:00:00:00", Rates.f47_95()})

      error = assert_raise Framestamp.MixedRateArithmeticError, fn -> Range.intersection!(a, b) end
      assert error.func_name == :intersection
      assert error.left_rate == Rates.f23_98()
      assert error.right_rate == Rates.f47_95()
    end

    test "errors on mixed out type" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = {"01:00:00:00", "04:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()

      error = assert_raise Framestamp.Range.MixedOutTypeArithmeticError, fn -> Range.intersection!(a, b) end
      assert error.func_name == :intersection
      assert error.left_out_type == :exclusive
      assert error.right_out_type == :inclusive
    end
  end

  describe "separation/2" do
    setup context, do: TestCase.setup_ranges(context)
    setup [:setup_inclusives]
    setup context, do: TestCase.setup_negates(context)
    setup [:setup_overlap_expected]

    @describetag ranges: [:a, :b, :expected]

    separation_table = [
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

    table_test "<%= name %> | :exclusive", separation_table, test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.separation(a, b) == expected
    end

    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | :exclusive | negative", separation_table, test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.separation(a, b) == expected
    end

    @tag inclusive: [:a, :b, :expected]
    table_test "<%= name %> | :inclusive", separation_table, test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.separation(a, b) == expected
    end

    @tag inclusive: [:a, :b, :expected]
    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | :inclusive | negative", separation_table, test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.separation(a, b) == expected
    end

    table_test "<%= name %> | :exclusive  | flipped", separation_table, test_case, if: test_case.a != test_case.b do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.separation(b, a) == expected
    end

    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | :exclusive | flipped | negative", separation_table, test_case,
      if: test_case.a != test_case.b do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.separation(b, a) == expected
    end

    @tag inclusive: [:a, :b, :expected]
    table_test "<%= name %> | :inclusive  | flipped", separation_table, test_case, if: test_case.a != test_case.b do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.separation(b, a) == expected
    end

    @tag inclusive: [:a, :b, :expected]
    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | :inclusive  | flipped | negative", separation_table, test_case,
      if: test_case.a != test_case.b do
      %{a: a, b: b, expected: expected} = test_case
      assert Range.separation(b, a) == expected
    end

    test "inherits rate in mixed rate operations | :left" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00", Rates.f23_98()})
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00", Rates.f47_95()})
      expected = TestCase.setup_range({"02:00:00:00", "03:00:00:00", Rates.f23_98()})

      assert {:ok, result} = Range.separation(a, b, inherit_rate: :left, inherit_out_type: :left)
      assert result == expected
    end

    test "inherits rate in mixed rate operations | :right" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00", Rates.f23_98()})
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00", Rates.f47_95()})
      expected = TestCase.setup_range({"02:00:00:00", "03:00:00:00", Rates.f47_95()})

      assert {:ok, result} = Range.separation(a, b, inherit_rate: :right, inherit_out_type: :right)
      assert result == expected
    end

    test "inherits out_type in mixed type operations | :left" do
      a = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00"})
      expected = {"02:00:00:00", "03:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()

      assert {:ok, result} = Range.separation(a, b, inherit_rate: :left, inherit_out_type: :left)
      assert result == expected
    end

    test "inherits out_type in mixed type operations | :right" do
      a = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00"})
      expected = TestCase.setup_range({"02:00:00:00", "03:00:00:00"})

      assert {:ok, result} = Range.separation(a, b, inherit_rate: :right, inherit_out_type: :right)
      assert result == expected
    end

    test "errors on mixed rate" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00", Rates.f47_95()})

      error = assert_raise Framestamp.MixedRateArithmeticError, fn -> Range.separation(a, b) end
      assert error.func_name == :separation
      assert error.left_rate == Rates.f23_98()
      assert error.right_rate == Rates.f47_95()
    end

    test "errors on mixed out type" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = {"03:00:00:00", "04:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()

      error = assert_raise Framestamp.Range.MixedOutTypeArithmeticError, fn -> Range.separation(a, b) end
      assert error.func_name == :separation
      assert error.left_out_type == :exclusive
      assert error.right_out_type == :inclusive
    end
  end

  describe "#separation!/2" do
    test "returns bare range on success" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00"})

      expected = TestCase.setup_range({"02:00:00:00", "03:00:00:00"})
      assert Range.separation!(a, b) == expected
    end

    test "returns zero-length range when overlap" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})

      expected = TestCase.setup_range({"00:00:00:00", "00:00:00:00"})
      assert Range.separation!(a, b) == expected
    end

    test "zero-length inherits rate in mixed rate operations | :left" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00", Rates.f47_95()})
      b = TestCase.setup_range({"01:00:00:00", "02:00:00:00", Rates.f23_98()})

      expected = TestCase.setup_range({"00:00:00:00", "00:00:00:00", Rates.f47_95()})
      assert Range.separation!(a, b, inherit_rate: :left, inherit_out_type: :left) == expected
    end

    test "zero-length inherits rate in mixed rate operations | :right" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00", Rates.f47_95()})
      b = TestCase.setup_range({"01:00:00:00", "02:00:00:00", Rates.f23_98()})

      expected = TestCase.setup_range({"00:00:00:00", "00:00:00:00", Rates.f23_98()})
      assert Range.separation!(a, b, inherit_rate: :right, inherit_out_type: :right) == expected
    end

    test "zero-length inherits out_type | :left" do
      a = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()
      b = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})

      expected = {"00:00:00:00", "00:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()
      assert Range.separation!(a, b, inherit_rate: :left, inherit_out_type: :left) == expected
    end

    test "zero-length inherits out_type | :right" do
      a = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()
      b = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})

      expected = TestCase.setup_range({"00:00:00:00", "00:00:00:00"})
      assert Range.separation!(a, b, inherit_rate: :right, inherit_out_type: :right) == expected
    end

    test "errors on mixed rate" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = TestCase.setup_range({"03:00:00:00", "04:00:00:00", Rates.f47_95()})

      error = assert_raise Framestamp.MixedRateArithmeticError, fn -> Range.separation(a, b) end
      assert error.func_name == :separation
      assert error.left_rate == Rates.f23_98()
      assert error.right_rate == Rates.f47_95()
    end

    test "errors on mixed out type" do
      a = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})
      b = {"03:00:00:00", "04:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()

      error = assert_raise Framestamp.Range.MixedOutTypeArithmeticError, fn -> Range.separation(a, b) end
      assert error.func_name == :separation
      assert error.left_out_type == :exclusive
      assert error.right_out_type == :inclusive
    end
  end

  describe "String.Chars.to_string/1" do
    test "renders expected for :exclusive" do
      range = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})

      assert String.Chars.to_string(range) ==
               "<01:00:00:00 - 02:00:00:00 :exclusive <23.98 NTSC>>"
    end

    test "renders expected for :inclusive" do
      range = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()

      assert String.Chars.to_string(range) ==
               "<01:00:00:00 - 01:59:59:23 :inclusive <23.98 NTSC>>"
    end
  end

  describe "Inspect.inspect/2" do
    test "renders expected for :exclusive" do
      range = TestCase.setup_range({"01:00:00:00", "02:00:00:00"})

      assert Inspect.inspect(range, Inspect.Opts.new([])) ==
               "<01:00:00:00 - 02:00:00:00 :exclusive <23.98 NTSC>>"
    end

    test "renders expected for :inclusive" do
      range = {"01:00:00:00", "02:00:00:00"} |> TestCase.setup_range() |> Range.with_inclusive_out()

      assert Inspect.inspect(range, Inspect.Opts.new([])) ==
               "<01:00:00:00 - 01:59:59:23 :inclusive <23.98 NTSC>>"
    end
  end

  # Males specified ranges built by setup_ranges out-inclusive.
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
