defmodule Vtc.Ecto.Postgres.PgFramestampRangeTest do
  use Vtc.Test.Support.EctoCase, async: true
  use ExUnitProperties

  alias Ecto.Query
  alias Vtc.Framestamp
  alias Vtc.Rates
  alias Vtc.Test.Support.CommonTables
  alias Vtc.TestUtls.StreamDataVtc

  require Ecto.Query

  describe "#SELECT" do
    setup context, do: TestCase.setup_ranges(context)

    @describetag ranges: [:input, :expected]

    canonical_table = [
      %{
        input: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "02:00:00:00"}
      },
      %{
        input: {"01:00:00:00", "02:00:00:00", :inclusive},
        expected: {"01:00:00:00", "02:00:00:01"}
      }
    ]

    table_test "type/2 fragment canonicalized to :inclusive range | <%= input %>", canonical_table, test_case do
      %{input: input, expected: expected} = test_case

      query = Query.from(f in fragment("SELECT ? as r", type(^input, Framestamp.Range)), select: f.r)

      assert %Postgrex.Range{} = result = Repo.one!(query)
      assert {:ok, ^expected} = Framestamp.Range.load(result)
    end

    table_test "native cast canonicalized to :inclusive range | <%= input %>", canonical_table, test_case do
      %{input: %{in: in_stamp, out: out_stamp} = input, expected: expected} = test_case
      range_bounds = if input.out_type == :exclusive, do: "[)", else: "[]"

      query =
        Query.from(
          f in fragment(
            "SELECT framestamp_range(?, ?, ?) as r",
            type(^in_stamp, Framestamp),
            type(^out_stamp, Framestamp),
            ^range_bounds
          ),
          select: f.r
        )

      assert %Postgrex.Range{} = result = Repo.one!(query)
      assert {:ok, ^expected} = Framestamp.Range.load(result)
    end
  end

  describe "Postgres @> and <@ (contains)" do
    setup context, do: TestCase.setup_framestamps(context)
    setup context, do: TestCase.setup_ranges(context)
    setup context, do: TestCase.setup_negates(context)

    @describetag framestamps: [:framestamp]
    @describetag ranges: [:range]

    table_test "<%= name %> | @>", CommonTables.range_contains(), test_case do
      %{range: range, framestamp: framestamp, expected: expected} = test_case

      query =
        Query.from(
          f in fragment(
            "SELECT ? @> ? as r",
            type(^range, Framestamp.Range),
            type(^framestamp, Framestamp)
          ),
          select: f.r
        )

      assert Repo.one!(query) == expected
    end

    table_test "<%= name %> | not @>", CommonTables.range_contains(), test_case do
      %{range: range, framestamp: framestamp, expected: expected} = test_case

      query =
        Query.from(
          f in fragment(
            "SELECT not ? @> ? as r",
            type(^range, Framestamp.Range),
            type(^framestamp, Framestamp)
          ),
          select: f.r
        )

      refute Repo.one!(query) == expected
    end

    @tag negate: [:range, :framestamp]
    table_test "<%= name %> | @> | negative", CommonTables.range_contains(), test_case do
      %{range: range, framestamp: framestamp, expected_negative: expected} = test_case

      query =
        Query.from(
          f in fragment(
            "SELECT ? @> ? as r",
            type(^range, Framestamp.Range),
            type(^framestamp, Framestamp)
          ),
          select: f.r
        )

      assert Repo.one!(query) == expected
    end

    @tag negate: [:range, :framestamp]
    table_test "<%= name %> | not @> | negative", CommonTables.range_contains(), test_case do
      %{range: range, framestamp: framestamp, expected_negative: expected} = test_case

      query =
        Query.from(
          f in fragment(
            "SELECT not ? @> ? as r",
            type(^range, Framestamp.Range),
            type(^framestamp, Framestamp)
          ),
          select: f.r
        )

      refute Repo.one!(query) == expected
    end

    table_test "<%= name %> | <@", CommonTables.range_contains(), test_case do
      %{range: range, framestamp: framestamp, expected: expected} = test_case

      query =
        Query.from(
          f in fragment(
            "SELECT ? <@ ? as r",
            type(^framestamp, Framestamp),
            type(^range, Framestamp.Range)
          ),
          select: f.r
        )

      assert Repo.one!(query) == expected
    end

    @tag negate: [:range, :framestamp]
    table_test "<%= name %> | <@ | negative", CommonTables.range_contains(), test_case do
      %{range: range, framestamp: framestamp, expected_negative: expected} = test_case

      query =
        Query.from(
          f in fragment(
            "SELECT ? <@ ? as r",
            type(^framestamp, Framestamp),
            type(^range, Framestamp.Range)
          ),
          select: f.r
        )

      assert Repo.one!(query) == expected
    end

    property "@> | matches Framestamp.Range.contains?/2" do
      check all(
              range <- StreamDataVtc.framestamp_range(),
              framestamp <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(
            f in fragment(
              "SELECT ? @> ? as r",
              type(^range, Framestamp.Range),
              type(^framestamp, Framestamp)
            ),
            select: f.r
          )

        assert Repo.one!(query) == Framestamp.Range.contains?(range, framestamp)
      end
    end

    property "<@ | matches Framestamp.Range.contains?/2" do
      check all(
              range <- StreamDataVtc.framestamp_range(),
              framestamp <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(
            f in fragment(
              "SELECT ? <@ ? as r",
              type(^framestamp, Framestamp),
              type(^range, Framestamp.Range)
            ),
            select: f.r
          )

        assert Repo.one!(query) == Framestamp.Range.contains?(range, framestamp)
      end
    end
  end

  describe "Postgres && (overlaps)" do
    setup context, do: TestCase.setup_ranges(context)
    setup context, do: TestCase.setup_negates(context)

    @describetag framestamps: [:framestamp]
    @describetag ranges: [:a, :b]

    table_test "<%= name %> | :eclusive", CommonTables.range_overlaps(), test_case do
      run_overlaps_select_test(test_case)
    end

    table_test "<%= name %> | :exclusive | flipped", CommonTables.range_overlaps(), test_case,
      if: test_case.a != test_case.b do
      %{a: a, b: b} = test_case

      test_case
      |> Map.put(:a, b)
      |> Map.put(:b, a)
      |> run_overlaps_select_test()
    end

    @tag out_type: :inclusive
    table_test "<%= name %> | :inclusive", CommonTables.range_overlaps(), test_case do
      %{a: a, b: b} = test_case

      a = Framestamp.Range.with_inclusive_out(a)
      b = Framestamp.Range.with_inclusive_out(b)

      test_case
      |> Map.put(:a, a)
      |> Map.put(:b, b)
      |> run_overlaps_select_test()
    end

    @tag out_type: :inclusive
    table_test "<%= name %> | :inclusive | flipped", CommonTables.range_overlaps(), test_case,
      if: test_case.a != test_case.b do
      %{a: a, b: b} = test_case

      a = Framestamp.Range.with_inclusive_out(a)
      b = Framestamp.Range.with_inclusive_out(b)

      test_case
      |> Map.put(:a, b)
      |> Map.put(:b, a)
      |> run_overlaps_select_test()
    end

    @tag negate: [:a, :b]
    table_test "<%= name %> | && | negative", CommonTables.range_overlaps(), test_case do
      run_overlaps_select_test(test_case)
    end

    @tag negate: [:a, :b]
    table_test "<%= name %> | && | negative | flipped", CommonTables.range_overlaps(), test_case do
      %{a: a, b: b} = test_case

      test_case
      |> Map.put(:a, b)
      |> Map.put(:b, a)
      |> run_overlaps_select_test()
    end

    table_test "<%= name %> | not &&", CommonTables.range_overlaps(), test_case do
      run_not_overlaps_select_test(test_case)
    end

    @tag negate: [:a, :b]
    table_test "<%= name %> | not && | negative", CommonTables.range_overlaps(), test_case do
      run_not_overlaps_select_test(test_case)
    end

    @spec run_overlaps_select_test(map()) :: :ok
    defp run_overlaps_select_test(test_case) do
      %{a: a, b: b, expected: expected} = test_case

      query =
        Query.from(
          f in fragment(
            "SELECT ? && ? as r",
            type(^a, Framestamp.Range),
            type(^b, Framestamp.Range)
          ),
          select: f.r
        )

      assert Repo.one!(query) == expected

      :ok
    end

    @spec run_not_overlaps_select_test(map()) :: :ok
    defp run_not_overlaps_select_test(test_case) do
      %{a: a, b: b, expected: expected} = test_case

      query =
        Query.from(
          f in fragment(
            "SELECT not ? && ? as r",
            type(^a, Framestamp.Range),
            type(^b, Framestamp.Range)
          ),
          select: f.r
        )

      refute Repo.one!(query) == expected

      :ok
    end

    property "matches Framestamp.Range.overlaps?/2" do
      check all(
              a <- StreamDataVtc.framestamp_range(filter_empty?: true),
              b <- StreamDataVtc.framestamp_range(filter_empty?: true)
            ) do
        query =
          Query.from(
            f in fragment(
              "SELECT ? && ? as r",
              type(^a, Framestamp.Range),
              type(^b, Framestamp.Range)
            ),
            select: f.r
          )

        assert Repo.one!(query) == Framestamp.Range.overlaps?(a, b)
      end
    end
  end

  describe "Postgres * (intersection)" do
    setup context, do: TestCase.setup_ranges(context)
    setup context, do: TestCase.setup_negates(context)

    @describetag framestamps: [:framestamp]
    @describetag ranges: [:a, :b, :expected]

    table_test "<%= name %>", CommonTables.range_intersection(), test_case, if: not (test_case.name =~ "mixed rate") do
      run_intersection_select_test(test_case)
    end

    table_test "<%= name %> | flipped", CommonTables.range_intersection(), test_case,
      if: not (test_case.name =~ "mixed rate") do
      %{a: a, b: b} = test_case

      test_case
      |> Map.put(:a, b)
      |> Map.put(:b, a)
      |> run_intersection_select_test()
    end

    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | negative", CommonTables.range_intersection(), test_case,
      if: not (test_case.name =~ "mixed rate") do
      run_intersection_select_test(test_case)
    end

    @tag negate: [:a, :b, :expected]
    table_test "<%= name %> | negative | flipped", CommonTables.range_intersection(), test_case,
      if: not (test_case.name =~ "mixed rate") do
      %{a: a, b: b} = test_case

      test_case
      |> Map.put(:a, b)
      |> Map.put(:b, a)
      |> run_intersection_select_test()
    end

    @spec run_intersection_select_test(map()) :: :ok
    defp run_intersection_select_test(test_case) do
      %{a: a, b: b, expected: expected} = test_case

      expected =
        case expected do
          {:error, :none} -> :error
          expected -> {:ok, expected}
        end

      query =
        Query.from(
          f in fragment(
            "SELECT ? * ? as r",
            type(^a, Framestamp.Range),
            type(^b, Framestamp.Range)
          ),
          select: f.r
        )

      result = query |> Repo.one!() |> Framestamp.Range.load()
      check_intersection_result(a, b, result, expected)

      :ok
    end

    property "matches Framestamp.Range.intersection/2" do
      check all(
              rate <- StreamDataVtc.framerate(),
              a <- StreamDataVtc.framestamp_range(stamp_opts: [rate: rate], filter_empty?: true),
              b <- StreamDataVtc.framestamp_range(stamp_opts: [rate: rate], filter_empty?: true)
            ) do
        expected =
          case Framestamp.Range.intersection(a, b) do
            {:ok, _} = result -> result
            {:error, :none} -> :error
          end

        query =
          Query.from(
            f in fragment(
              "SELECT ? * ? as r",
              type(^a, Framestamp.Range),
              type(^b, Framestamp.Range)
            ),
            select: f.r
          )

        result = query |> Repo.one!() |> Framestamp.Range.load()
        check_intersection_result(a, b, result, expected)
      end
    end

    @spec check_intersection_result(
            Framestamp.Range.t(),
            Framestamp.Range.t(),
            {:ok, Framestamp.Range.t()} | :error,
            {:ok, Framestamp.Range.t()} | :error
          ) :: :ok
    defp check_intersection_result(a, b, result, expected) do
      cond do
        expected == :error ->
          assert result == expected

        a.in.rate != b.in.rate ->
          {:ok, expected} = expected
          assert {:ok, result} = result
          expected_inverse = Framestamp.Range.intersection!(b, a)
          expected_flipped_inverse = Framestamp.Range.intersection!(a, b)

          assert result.in.rate == result.out.rate

          assert result.in == expected.in or
                   result.in == expected_inverse.in or
                   result.in == expected_flipped_inverse.in

          assert result.out == expected.out or
                   result.out == expected_inverse.out or
                   result.out == expected_flipped_inverse.out

        true ->
          assert result == expected
      end

      :ok
    end
  end

  describe "#SELECT fastrange/2" do
    test "can construct fastrange" do
      stamp_01 = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_02 = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      query =
        Query.from(
          f in fragment(
            "SELECT framestamp_fastrange(?, ?) as r",
            type(^stamp_01, Framestamp),
            type(^stamp_02, Framestamp)
          ),
          select: f.r
        )

      assert %Postgrex.Range{} = result = Repo.one!(query)
      assert result.lower == Ratio.to_float(stamp_01.seconds)
      assert result.upper == Ratio.to_float(stamp_02.seconds)
    end

    property "can construct fastrange from two framestamps" do
      check all(range <- StreamDataVtc.framestamp_range(filter_empty?: true)) do
        stamp_in = range.in
        stamp_out = range.out

        query =
          Query.from(
            f in fragment(
              "SELECT framestamp_fastrange(?, ?) as r",
              type(^stamp_in, Framestamp),
              type(^stamp_out, Framestamp)
            ),
            select: f.r
          )

        assert %Postgrex.Range{} = result = Repo.one!(query)
        assert result.lower == Ratio.to_float(stamp_in.seconds)
        assert result.upper == Ratio.to_float(stamp_out.seconds)
      end
    end

    test "can construct fastrange from Framestamp.Range" do
      stamp_01 = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_02 = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
      range = Framestamp.Range.new!(stamp_01, stamp_02)

      query =
        Query.from(
          f in fragment(
            "SELECT framestamp_fastrange(?) as r",
            type(^range, Framestamp.Range)
          ),
          select: f.r
        )

      assert %Postgrex.Range{} = result = Repo.one!(query)
      assert result.lower == Ratio.to_float(stamp_01.seconds)
      assert result.lower_inclusive == true
      assert result.upper == Ratio.to_float(stamp_02.seconds)
      assert result.upper_inclusive == false
    end

    test "can construct fastrange from exclusive Framestamp.Range" do
      stamp_01 = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      stamp_02 = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
      range = Framestamp.Range.new!(stamp_01, stamp_02, out_type: :inclusive)
      expected = Framestamp.Range.with_exclusive_out(range)

      query =
        Query.from(
          f in fragment(
            "SELECT framestamp_fastrange(?) as r",
            type(^range, Framestamp.Range)
          ),
          select: f.r
        )

      assert %Postgrex.Range{} = result = Repo.one!(query)
      assert result.lower == Ratio.to_float(expected.in.seconds)
      assert result.lower_inclusive == true
      assert result.upper == Ratio.to_float(expected.out.seconds)
      assert result.upper_inclusive == false
    end
  end
end
