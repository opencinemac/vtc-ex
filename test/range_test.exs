defmodule Vtc.RangeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Vtc.Range
  alias Vtc.Rates
  alias Vtc.Timecode

  @typedoc """
  Shorthand way to specify a {timecode_in, timecode_out, out_type} in a test case for a
  setup function to build the timecodes and ranges.

  Timecodes should be specified in strings and the setup will choose a framerate to
  apply.
  """
  @type range_shorthand() :: {String.t(), String.t(), Range.out_type()}

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

    test "errors on different rates" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("00:30:00:00", Rates.f24())

      assert {:error, error} = Range.with_duration(start_tc, duration)
      assert Exception.message(error) == "`tc_in` and `duration` must have same `rate`"
    end

    test "errors on negative duration" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("-00:30:00:00", Rates.f23_98())

      assert {:error, error} = Range.with_duration(start_tc, duration)
      assert Exception.message(error) == "`duration` must be greater than `0`"
    end

    test "errors on negative duration when out_type: :inclusive" do
      start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      duration = Timecode.with_frames!("-00:30:00:00", Rates.f23_98())

      assert {:error, error} = Range.with_duration(start_tc, duration, out_type: :inclusive)
      assert Exception.message(error) == "`duration` must be greater than `0`"
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

  describe "#overlaps?/2" do
    setup [:setup_ranges, :setup_negates]

    @describetag ranges: [:a, :b]

    @overlap_cases [
      %{
        name: "1.a == 2.a and 1.b == 2.b | :exclusive",
        a: {"01:00:00:00", "02:00:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: true
      },
      %{
        name: "1.a == 2.a and 1.b < 2.b | :exclusive",
        a: {"01:00:00:00", "01:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: true
      },
      %{
        name: "1.a == 2.a and 1.b > 2.b | :exclusive",
        a: {"01:00:00:00", "02:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: true
      },
      %{
        name: "1.a < 2.a and 1.b == 2.b | :exclusive",
        a: {"00:30:00:00", "02:00:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: true
      },
      %{
        name: "1.a < 2.a and 1.b < 2.b | :exclusive",
        a: {"00:30:00:00", "01:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: true
      },
      %{
        name: "1.a < 2.a and 1.b > 2.b | :exclusive",
        a: {"00:30:00:00", "02:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: true
      },
      %{
        name: "1.a > 2.a and 1.b == 2.b | :exclusive",
        a: {"01:30:00:00", "02:00:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: true
      },
      %{
        name: "1.a > 2.a and 1.b < 2.b | :exclusive",
        a: {"01:15:00:00", "01:45:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: true
      },
      %{
        name: "1.a > 2.a and 1.b > 2.b | :exclusive",
        a: {"01:30:00:00", "02:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: true
      },
      %{
        name: "a < b | :exclusive",
        a: {"00:00:00:00", "00:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: false
      },
      %{
        name: "a > b | :exclusive",
        a: {"02:30:00:00", "03:00:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: false
      },
      %{
        name: "1.b & 1.a at boundary | :exclusive",
        a: {"01:00:00:00", "02:00:00:00", :exclusive},
        b: {"02:00:00:00", "03:00:00:00", :exclusive},
        expected: false
      },
      %{
        name: "1.a & 1.b at boundary | :exclusive",
        a: {"03:00:00:00", "04:00:00:00", :exclusive},
        b: {"02:00:00:00", "03:00:00:00", :exclusive},
        expected: false
      },
      %{
        name: "1.b & 1.a at boundary | :inclusive",
        a: {"00:00:00:00", "00:59:59:23", :inclusive},
        b: {"01:00:00:00", "02:00:00:00", :inclusive},
        expected: false
      },
      %{
        name: "1.a & 1.b at boundary | :inclusive",
        a: {"02:00:00:01", "03:00:00:00", :inclusive},
        b: {"01:00:00:00", "02:00:00:00", :inclusive},
        expected: false
      }
    ]

    for test_case <- @overlap_cases do
      @tag test_case: test_case
      test test_case.name, context do
        %{a: a, b: b, test_case: %{expected: expected}} = context
        assert Range.overlaps?(a, b) == expected
      end

      @tag test_case: test_case
      @tag negate: [:a, :b]
      test "#{test_case.name} | negative", context do
        %{a: a, b: b, test_case: %{expected: expected}} = context
        assert Range.overlaps?(a, b) == expected
      end

      if test_case.a != test_case.b do
        @tag test_case: test_case
        test "#{test_case.name} | flipped", context do
          %{a: a, b: b, test_case: %{expected: expected}} = context
          assert Range.overlaps?(b, a) == expected
        end

        @tag test_case: test_case
        @tag negate: [:a, :b]
        test "#{test_case.name} | flipped | negative", context do
          %{a: a, b: b, test_case: %{expected: expected}} = context
          assert Range.overlaps?(b, a) == expected
        end
      end
    end
  end

  describe "intersection/2" do
    setup [:setup_ranges]

    @describetag ranges: [:a, :b, :expected]

    @intersection_cases [
      %{
        name: "1.a == 2.a and 1.b == 2.b",
        a: {"01:00:00:00", "02:00:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: {"01:00:00:00", "02:00:00:00", :exclusive}
      },
      %{
        name: "1.a == 2.a and 1.b < 2.b",
        a: {"01:00:00:00", "01:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: {"01:00:00:00", "01:30:00:00", :exclusive}
      },
      %{
        name: "1.a == 2.a and 1.b > 2.b",
        a: {"01:00:00:00", "02:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: {"01:00:00:00", "02:00:00:00", :exclusive}
      },
      %{
        name: "1.a < 2.a and 1.b == 2.b",
        a: {"00:30:00:00", "02:00:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: {"01:00:00:00", "02:00:00:00", :exclusive}
      },
      %{
        name: "1.a < 2.a and 1.b < 2.b",
        a: {"00:30:00:00", "01:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: {"01:00:00:00", "01:30:00:00", :exclusive}
      },
      %{
        name: "1.a < 2.a and 1.b > 2.b",
        a: {"00:30:00:00", "02:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: {"01:00:00:00", "02:00:00:00", :exclusive}
      },
      %{
        name: "1.a > 2.a and 1.b == 2.b",
        a: {"01:30:00:00", "02:00:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: {"01:30:00:00", "02:00:00:00", :exclusive}
      },
      %{
        name: "1.a > 2.a and 1.b < 2.b",
        a: {"01:15:00:00", "01:45:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: {"01:15:00:00", "01:45:00:00", :exclusive}
      },
      %{
        name: "1.a > 2.a and 1.b > 2.b",
        a: {"01:30:00:00", "02:30:00:00", :exclusive},
        b: {"01:00:00:00", "02:00:00:00", :exclusive},
        expected: {"01:30:00:00", "02:00:00:00", :exclusive}
      }
    ]

    for test_case <- @intersection_cases do
      @tag test_case: test_case
      test test_case.name, context do
        %{a: a, b: b, expected: expected} = context
        assert Range.intersection(a, b) == expected
      end

      if test_case.a != test_case.b do
        @tag test_case: test_case
        test "#{test_case.name} | flipped", context do
          %{a: a, b: b, expected: expected} = context
          assert Range.intersection(b, a) == expected
        end
      end
    end
  end

  # Turns specified test case range shorthands into full blown ranges.
  @spec setup_ranges(%{optional(:ranges) => [Map.key()], :test_case => map()}) :: Keyword.t()
  defp setup_ranges(%{ranges: attrs, test_case: test_case}) do
    test_case
    |> Map.take(attrs)
    |> Enum.into([])
    |> Enum.map(fn {name, values} -> {name, setup_range(values)} end)
  end

  defp setup_ranges(context), do: context

  @spec setup_range(range_shorthand()) :: Range.t()
  defp setup_range(values) do
    {in_tc, out_tc, out_type} = values

    in_tc = Timecode.with_frames!(in_tc, Rates.f23_98())
    out_tc = Timecode.with_frames!(out_tc, Rates.f23_98())
    range = %Range{in: in_tc, out: out_tc, out_type: out_type}

    range
  end

  # Negates secified ranges built by setup_ranges.
  @spec setup_negates(%{optional(:negate) => [Map.key()], :test_case => map()}) :: Keyword.t()
  defp setup_negates(%{negate: attrs} = context) do
    context
    |> Map.take(attrs)
    |> Enum.into([])
    |> Enum.map(fn {name, value} -> {name, setup_negate(value)} end)
  end

  defp setup_negates(context), do: context

  @spec setup_negate(Range.t()) :: Range.t()
  defp setup_negate(range) do
    %Range{in: in_tc, out: out_tc} = range
    %Range{range | in: Timecode.negate(out_tc), out: Timecode.negate(in_tc)}
  end
end
