defmodule Vtc.Ecto.Postgres.PgRationalTest do
  use Vtc.Test.Support.EctoCase, async: true
  use ExUnitProperties

  alias Ecto.Query
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Test.Support.RationalsSchema01
  alias Vtc.Test.Support.RationalsSchema02
  alias Vtc.TestUtls.StreamDataVtc

  require Ecto.Query

  describe "#cast/1" do
    test "succeeds with %Ratio{} struct" do
      assert PgRational.cast(Ratio.new(3, 4)) == {:ok, Ratio.new(3, 4)}
    end

    test "succeeds with 2-item array" do
      assert PgRational.cast([3, 4]) == {:ok, Ratio.new(3, 4)}
    end

    test "succeeds with rational string" do
      assert PgRational.cast("3/4") == {:ok, Ratio.new(3, 4)}
    end

    test "fails with with map" do
      assert PgRational.cast(%{numerator: 3, denominator: 4}) == :error
    end

    test "fails with 2-item tuple" do
      assert PgRational.cast({3, 4}) == :error
    end

    test "fails with 3-item array" do
      assert PgRational.cast([3, 4, 5]) == :error
    end

    test "fails with non-rationl string" do
      assert PgRational.cast("3,4") == :error
    end

    test "fails with extra `/` characters" do
      assert PgRational.cast("3/4/") == :error
    end

    test "fails with bad whitespace" do
      assert PgRational.cast(" 3/4 ") == :error
    end

    test "fails with bad trailing whitespace" do
      assert PgRational.cast("3/4 ") == :error
    end

    property "succeeds on %Ratio{} struct" do
      check all(rational <- StreamDataVtc.rational()) do
        assert {:ok, ^rational} = PgRational.cast(rational)
      end
    end

    property "succeeds on array" do
      check all(rational <- StreamDataVtc.rational()) do
        assert {:ok, ^rational} = PgRational.cast([rational.numerator, rational.denominator])
      end
    end

    property "succeeds on rational string" do
      check all(rational <- StreamDataVtc.rational()) do
        rational_str = "#{rational.numerator}/#{rational.denominator}"
        assert {:ok, ^rational} = PgRational.cast(rational_str)
      end
    end
  end

  describe "#dump/1" do
    test "succeeds on %Ratio{}" do
      assert {:ok, {3, 4}} = PgRational.dump(Ratio.new(3, 4))
    end

    test "fails on map" do
      assert :error = PgRational.dump(%{numerator: 3, denominator: 4})
    end

    test "fails on array" do
      assert :error = PgRational.dump([3, 4])
    end

    test "fails on string" do
      assert :error = PgRational.dump("3/4")
    end

    property "succeeds on %Ratio{} values" do
      check all(rational <- StreamDataVtc.rational()) do
        assert {:ok, {numerator, denominator}} = PgRational.dump(rational)
        assert numerator == rational.numerator
        assert denominator == rational.denominator
      end
    end
  end

  describe "#load/1" do
    test "succeeds on {integer, integer} tuple" do
      assert {:ok, result} = PgRational.load({3, 4})
      assert result == Ratio.new(3, 4)
    end

    test "fails on map" do
      assert :error = PgRational.load(%{numerator: 3, denominator: 4})
    end

    test "fails on array" do
      assert :error = PgRational.load([3, 4])
    end

    test "fails on SQL string" do
      assert :error = PgRational.load("(3, 4)")
    end

    test "fails on rational string" do
      assert :error = PgRational.load("3/4")
    end

    property "succeeds on {integer, integer} tuple" do
      check all(rational <- StreamDataVtc.rational()) do
        assert {:ok, result} = PgRational.load({rational.numerator, rational.denominator})
        assert result == rational
      end
    end
  end

  describe "SELECT queries | No Table" do
    test "can select rational" do
      query = Query.from(f in fragment("SELECT (3, 4)::rational as r"), select: f.r)
      assert {3, 4} = Repo.one!(query)
    end

    test "can cast %Ratio{} struct to DB value" do
      rational = PgRational.dump!(Ratio.new(3, 4))
      query = Query.from(f in fragment("SELECT ?::rational as r", ^rational), select: f.r)

      assert {3, 4} = Repo.one!(query)
    end

    test "can select numerator" do
      query = Query.from(f in fragment("SELECT ((3, 4)::rational).numerator as n"), select: f.n)
      assert 3 = Repo.one!(query)
    end

    test "can select denominator" do
      query = Query.from(f in fragment("SELECT ((3, 4)::rational).denominator as d"), select: f.d)
      assert 4 = Repo.one!(query)
    end

    property "can SELECT rational values" do
      check all(rational <- StreamDataVtc.rational()) do
        rational_sql = PgRational.dump!(rational)

        query = Query.from(f in fragment("SELECT ?::rational as r", ^rational_sql), select: f.r)

        assert {numerator, denominator} = Repo.one!(query)
        assert numerator == rational.numerator
        assert denominator == rational.denominator
      end
    end
  end

  describe "basic table serialization" do
    setup [:setup_record_01]

    @tag skip_setup_record_01?: true
    property "can insert records without checks" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        assert {:ok, record} =
                 %RationalsSchema01{}
                 |> RationalsSchema01.changeset(%{a: a, b: b})
                 |> Repo.insert()

        assert %RationalsSchema01{} = record
        assert record.a == a
        assert record.b == b
      end
    end

    @tag skip_setup_record_01?: true
    property "can insert records with checks" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        assert {:ok, record} =
                 %RationalsSchema02{}
                 |> RationalsSchema02.changeset(%{a: a, b: b})
                 |> Repo.insert()

        assert %RationalsSchema02{} = record
        assert record.a == a
        assert record.b == b
      end
    end

    test "fetch a record", context do
      %{record_01: record_01} = context

      assert %RationalsSchema01{} = record = Repo.get(RationalsSchema01, record_01.id)
      assert record.a == Ratio.new(1, 2)
      assert record.b == Ratio.new(3, 4)
    end

    @tag skip_setup_record_01?: true
    test "rationals_02.a cannot have 0 denom" do
      assert {:error, error} =
               Repo.query("""
               INSERT INTO rationals_02 (id, a, b)
               VALUES ('#{Ecto.UUID.generate()}', (1, 0)::rational, (3, 4)::rational)
               """)

      assert %Postgrex.Error{postgres: %{code: :check_violation, constraint: "a_denominator_positive"}} = error
    end

    property "rationals_02.a denominator must be positive" do
      check all(
              numerator <- StreamData.integer(),
              denominator <- StreamData.filter(StreamData.integer(), &(&1 <= 0))
            ) do
        assert {:error, error} =
                 Repo.query("""
                 INSERT INTO rationals_02 (id, a, b)
                 VALUES ('#{Ecto.UUID.generate()}', (#{numerator}, #{denominator})::rational, (3, 4)::rational)
                 """)

        assert %Postgrex.Error{postgres: %{code: :check_violation, constraint: "a_denominator_positive"}} = error
      end
    end

    @tag skip_setup_record_01?: true
    test "rationals_02.b cannot have 0 denom" do
      assert {:error, error} =
               Repo.query("""
               INSERT INTO rationals_02 (id, a, b)
               VALUES ('#{Ecto.UUID.generate()}', (1, 2)::rational, (3, -1)::rational)
               """)

      assert %Postgrex.Error{postgres: %{code: :check_violation, constraint: "b_denominator_positive"}} = error
    end

    property "rationals_02.b denominator must be positive" do
      check all(
              numerator <- StreamData.integer(),
              denominator <- StreamData.filter(StreamData.integer(), &(&1 <= 0))
            ) do
        assert {:error, error} =
                 Repo.query("""
                 INSERT INTO rationals_02 (id, a, b)
                 VALUES ('#{Ecto.UUID.generate()}', (1, 2)::rational, (#{numerator}, #{denominator})::rational)
                 """)

        assert %Postgrex.Error{postgres: %{code: :check_violation, constraint: "b_denominator_positive"}} = error
      end
    end
  end

  describe "#Postgres rational_private.greatest_common_denominator/2" do
    gcd_table = [
      %{a: 2, b: 4, expected: 2},
      %{a: 21, b: 14, expected: 7},
      %{a: 23, b: 14, expected: 1},
      %{a: 1000, b: 70, expected: 10}
    ]

    table_test "<%= a %>, <%= b %> == <%= expected %>", gcd_table, test_case do
      %{a: a, b: b, expected: expected} = test_case

      assert %Postgrex.Result{rows: rows} = Repo.query!("SELECT rational_private.greatest_common_denominator(#{a}, #{b})")

      assert [[^expected]] = rows
    end

    table_test "-<%= a %>, <%= b %> == <%= expected %>", gcd_table, test_case do
      %{a: a, b: b, expected: expected} = test_case

      assert %Postgrex.Result{rows: rows} =
               Repo.query!("SELECT rational_private.greatest_common_denominator(-#{a}, #{b})")

      assert [[^expected]] = rows
    end

    table_test "<%= a %>, -<%= b %> == <%= expected %>", gcd_table, test_case do
      %{a: a, b: b, expected: expected} = test_case

      assert %Postgrex.Result{rows: rows} =
               Repo.query!("SELECT rational_private.greatest_common_denominator(#{a}, -#{b})")

      assert [[^expected]] = rows
    end

    table_test "-<%= a %>, -<%= b %> == <%= expected %>", gcd_table, test_case do
      %{a: a, b: b, expected: expected} = test_case

      assert %Postgrex.Result{rows: rows} =
               Repo.query!("SELECT rational_private.greatest_common_denominator(-#{a}, -#{b})")

      assert [[^expected]] = rows
    end
  end

  describe "#Postgres rational_private.simplify/1" do
    simplify_table = [
      %{numerator: 2, denominator: 4, expected: Ratio.new(1, 2)},
      %{numerator: -2, denominator: 4, expected: Ratio.new(-1, 2)},
      %{numerator: 2, denominator: -4, expected: Ratio.new(-1, 2)},
      %{numerator: -2, denominator: -4, expected: Ratio.new(1, 2)},
      %{numerator: 10, denominator: 100, expected: Ratio.new(1, 10)},
      %{numerator: 3, denominator: 39, expected: Ratio.new(1, 13)},
      %{numerator: 4, denominator: 9, expected: Ratio.new(4, 9)}
    ]

    table_test "<%= numerator %>/<%= denominator %> == <%= expected %>", simplify_table, test_case do
      %{numerator: numerator, denominator: denominator, expected: expected} = test_case

      assert %Postgrex.Result{rows: [[db_record]]} =
               Repo.query!("SELECT rational_private.simplify((#{numerator}, #{denominator})::rational)")

      assert db_record == {expected.numerator, expected.denominator}
    end

    property "mirrors Ratio.new" do
      check all(
              numerator <- StreamData.integer(),
              denominator <- StreamData.filter(StreamData.integer(), &(&1 != 0))
            ) do
        expected = Ratio.new(numerator, denominator)

        assert %Postgrex.Result{rows: [[{db_numerator, db_denominator}]]} =
                 Repo.query!("SELECT rational_private.simplify((#{numerator}, #{denominator})::rational)")

        assert db_numerator == expected.numerator
        assert db_denominator == expected.denominator
      end
    end
  end

  defp setup_record_01(%{skip_setup_record_01?: true}), do: []

  defp setup_record_01(_) do
    {:ok, record_01} =
      %RationalsSchema01{}
      |> RationalsSchema01.changeset(%{a: Ratio.new(1, 2), b: Ratio.new(3, 4)})
      |> Repo.insert()

    [record_01: record_01]
  end
end
