defmodule Vtc.Ecto.Postgres.PgRationalTest do
  use Vtc.Test.Support.EctoCase, async: true
  use ExUnitProperties

  alias Ecto.Query
  alias Ecto.Repo.Queryable
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Test.Support.RationalsSchema01
  alias Vtc.Test.Support.RationalsSchema02
  alias Vtc.TestUtls.StreamDataVtc
  alias Vtc.Utils.Rational

  require Ecto.Query
  require PgRational

  describe "#cast/1" do
    cast_table = [
      %{input: Ratio.new(3, 4), expected: Ratio.new(3, 4)},
      %{input: Ratio.new(-3, 4), expected: Ratio.new(-3, 4)},
      %{input: [3, 4], expected: Ratio.new(3, 4)},
      %{input: [-3, 4], expected: Ratio.new(-3, 4)},
      %{input: "3/4", expected: Ratio.new(3, 4)},
      %{input: "-3/4", expected: Ratio.new(-3, 4)}
    ]

    table_test "succeeds with <%= input %>", cast_table, test_case do
      %{input: input, expected: expected} = test_case
      assert {:ok, ^expected} = PgRational.cast(input)
    end

    bad_cast_table = [
      %{input: %{numerator: 3, denominator: 4}},
      %{input: {3, 4}},
      %{input: [3, 4, 5]},
      %{input: "3,4"},
      %{input: "3/4/"},
      %{input: "3/4 "}
    ]

    table_test "fails with <%= input %>", bad_cast_table, test_case do
      %{input: input} = test_case
      assert :error = PgRational.cast(input)
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
    dump_table = [
      %{input: Ratio.new(3, 4), expected: {3, 4}},
      %{input: Ratio.new(-3, 4), expected: {-3, 4}}
    ]

    table_test "succeeds on <%= input %>", dump_table, test_case do
      %{input: input, expected: expected} = test_case
      assert {:ok, ^expected} = PgRational.dump(input)
    end

    bad_dump_table = [
      %{input: %{numerator: 3, denominator: 4}},
      %{input: [3, 4]},
      %{input: "3/4"}
    ]

    table_test "fails on <%= input %>", bad_dump_table, test_case do
      %{input: input} = test_case
      assert :error = PgRational.dump(input)
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
    load_table = [
      %{input: {3, 4}, expected: Ratio.new(3, 4)},
      %{input: {-3, 4}, expected: Ratio.new(-3, 4)}
    ]

    table_test "succeeds on <%= input %>", load_table, test_case do
      %{input: input, expected: expected} = test_case
      assert {:ok, ^expected} = PgRational.load(input)
    end

    bad_load_table = [
      %{input: %{numerator: 3, denominator: 4}},
      %{input: [3, 4]},
      %{input: "3/4"},
      %{input: "(3, 4)"}
    ]

    table_test "fails on <%= input %>", bad_load_table, test_case do
      %{input: input} = test_case
      assert :error = PgRational.load(input)
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
      rational = Ratio.new(3, 4)
      query = Query.from(f in fragment("SELECT ? as r", type(^rational, PgRational)), select: f.r)

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
        query = Query.from(f in fragment("SELECT ? as r", type(^rational, PgRational)), select: f.r)

        assert {numerator, denominator} = Repo.one!(query)
        assert numerator == rational.numerator
        assert denominator == rational.denominator
      end
    end
  end

  describe "basic table serialization" do
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

        assert %RationalsSchema01{} = record = Repo.get(RationalsSchema01, record.id)
        assert record.a == a
        assert record.b == b
      end
    end

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

        assert %RationalsSchema02{} = record = Repo.get(RationalsSchema02, record.id)
        assert record.a == a
        assert record.b == b
      end
    end

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

  describe "Postgres rational.minus/1" do
    property "matches Ratio" do
      check all(input <- StreamDataVtc.rational()) do
        query =
          Query.from(f in fragment("SELECT rational.minus(?) as r", type(^input, PgRational)),
            select: f.r
          )

        assert {:ok, result} = query |> Repo.one!() |> PgRational.load()
        assert result == Ratio.minus(input)
      end
    end

    test "can be used on table fields" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema01{}
               |> RationalsSchema01.changeset(%{a: Ratio.new(3, 4), b: Ratio.new(1, 1)})
               |> Repo.insert()

      assert {:ok, result} =
               RationalsSchema01
               |> Query.select([r], fragment("rational.minus(?)", r.a))
               |> Query.where([r], r.id == ^record_id)
               |> Repo.one!()
               |> PgRational.load()

      assert result == Ratio.new(-3, 4)
    end
  end

  describe "Postgres rational.abs/1" do
    property "matches Ratio" do
      check all(input <- StreamDataVtc.rational()) do
        query =
          Query.from(f in fragment("SELECT rational.abs(?) as r", type(^input, PgRational)),
            select: f.r
          )

        assert {:ok, result} = query |> Repo.one!() |> PgRational.load()
        assert result == Ratio.abs(input)
      end
    end

    test "can be used on table fields | negative" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema01{}
               |> RationalsSchema01.changeset(%{a: Ratio.new(-3, 4), b: Ratio.new(1, 1)})
               |> Repo.insert()

      assert {:ok, result} =
               RationalsSchema01
               |> Query.select([r], fragment("rational.abs(?)", r.a))
               |> Query.where([r], r.id == ^record_id)
               |> Repo.one!()
               |> PgRational.load()

      assert result == Ratio.new(3, 4)
    end

    test "can be used on table fields | positive" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema01{}
               |> RationalsSchema01.changeset(%{a: Ratio.new(3, 4), b: Ratio.new(1, 1)})
               |> Repo.insert()

      assert {:ok, result} =
               RationalsSchema01
               |> Query.select([r], fragment("rational.abs(?)", r.a))
               |> Query.where([r], r.id == ^record_id)
               |> Repo.one!()
               |> PgRational.load()

      assert result == Ratio.new(3, 4)
    end
  end

  describe "Postgres rational.round/1" do
    round_table = [
      %{input: Ratio.new(1), expected: 1},
      %{input: Ratio.new(-1), expected: -1},
      %{input: Ratio.new(1, 2), expected: 1},
      %{input: Ratio.new(-1, 2), expected: -1},
      %{input: Ratio.new(1, 4), expected: 0},
      %{input: Ratio.new(-1, 4), expected: 0},
      %{input: Ratio.new(3, 4), expected: 1},
      %{input: Ratio.new(-3, 4), expected: -1}
    ]

    table_test "<%= input %> = <%= expected %>", round_table, test_case do
      %{input: input, expected: expected} = test_case

      query =
        Query.from(f in fragment("SELECT rational.round(?) as r", type(^input, PgRational)),
          select: f.r
        )

      result = Repo.one!(query)
      assert is_integer(result)
      assert result == expected
    end

    property "matches Ratio" do
      check all(input <- StreamDataVtc.rational()) do
        query =
          Query.from(f in fragment("SELECT rational.round(?) as r", type(^input, PgRational)),
            select: f.r
          )

        result = Repo.one!(query)
        assert is_integer(result)
        assert result == Rational.round(input)
      end
    end

    test "can be used on table fields" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema01{}
               |> RationalsSchema01.changeset(%{a: Ratio.new(3, 4), b: Ratio.new(1, 1)})
               |> Repo.insert()

      result =
        RationalsSchema01
        |> Query.select([r], fragment("rational.round(?)", r.a))
        |> Query.where([r], r.id == ^record_id)
        |> Repo.one!()

      assert result == 1
    end
  end

  describe "Postgres + (add)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        query =
          Query.from(f in fragment("SELECT ? + ? as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        assert {:ok, result} = query |> Repo.one!() |> PgRational.load()
        assert result == Ratio.add(a, b)
      end
    end

    test "can be used on table fields" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(3, 4), b: Ratio.new(1, 2)})
               |> Repo.insert()

      assert {:ok, result} =
               RationalsSchema02
               |> Query.select([r], r.a + r.b)
               |> Query.where([r], r.id == ^record_id)
               |> Repo.one!()
               |> PgRational.load()

      assert result == Ratio.new(5, 4)
    end
  end

  describe "Postgres - (sub)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        query =
          Query.from(f in fragment("SELECT ? - ? as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        assert {:ok, result} = query |> Repo.one!() |> PgRational.load()
        assert result == Ratio.sub(a, b)
      end
    end

    test "can be used on table fields" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(3, 4), b: Ratio.new(1, 2)})
               |> Repo.insert()

      assert {:ok, result} =
               RationalsSchema02
               |> Query.select([r], r.a - r.b)
               |> Query.where([r], r.id == ^record_id)
               |> Repo.one!()
               |> PgRational.load()

      assert result == Ratio.new(1, 4)
    end
  end

  describe "Postgres * (multiply)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        query =
          Query.from(f in fragment("SELECT ? * ? as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        assert {:ok, result} = query |> Repo.one!() |> PgRational.load()
        assert result == Ratio.mult(a, b)
      end
    end

    test "can be used on table fields" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(23, 8), b: Ratio.new(4, 5)})
               |> Repo.insert()

      assert {:ok, result} =
               RationalsSchema02
               |> Query.select([r], r.a * r.b)
               |> Query.where([r], r.id == ^record_id)
               |> Repo.one!()
               |> PgRational.load()

      assert result == Ratio.new(23, 10)
    end
  end

  describe "Postgres / (divide)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0, 1))))
            ) do
        query =
          Query.from(f in fragment("SELECT ? / ? as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        assert {:ok, result} = query |> Repo.one!() |> PgRational.load()
        assert result == Ratio.div(a, b)
      end
    end

    test "can be used on table fields" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(23, 8), b: Ratio.new(4, 5)})
               |> Repo.insert()

      assert {:ok, result} =
               RationalsSchema02
               |> Query.select([r], r.a / r.b)
               |> Query.where([r], r.id == ^record_id)
               |> Repo.one!()
               |> PgRational.load()

      assert result == Ratio.new(115, 32)
    end
  end

  describe "Postgres % (modulo)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0, 1))))
            ) do
        expected = Rational.rem(a, b)

        query =
          Query.from(f in fragment("SELECT ? % ? as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        assert {:ok, result} = query |> Repo.one!() |> PgRational.load()
        assert result == expected
      end
    end

    test "can be used on table fields" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(23, 8), b: Ratio.new(4, 5)})
               |> Repo.insert()

      assert {:ok, result} =
               RationalsSchema02
               |> Query.select([r], fragment("? % ?", r.a, r.b))
               |> Query.where([r], r.id == ^record_id)
               |> Repo.one!()
               |> PgRational.load()

      expected = Rational.rem(Ratio.new(23, 8), Ratio.new(4, 5))
      assert result == expected
    end
  end

  describe "Postgres rational_private.comp/2" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0, 1))))
            ) do
        query =
          Query.from(
            f in fragment(
              "SELECT rational_private.cmp(?, ?) as r",
              type(^a, PgRational),
              type(^b, PgRational)
            ),
            select: f.r
          )

        result = Repo.one!(query)
        assert is_integer(result)

        expected =
          case Ratio.compare(a, b) do
            :lt -> -1
            :eq -> 0
            :gt -> 1
          end

        assert result == expected
      end
    end

    test "can be used on table fields" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(1, 2), b: Ratio.new(1, 4)})
               |> Repo.insert()

      assert result =
               RationalsSchema02
               |> Query.select([r], fragment("rational_private.cmp(?, ?)", r.a, r.b))
               |> Query.where([r], r.id == ^record_id)
               |> Repo.one!()

      assert result == 1
    end
  end

  describe "Postgres = (equals)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0, 1))))
            ) do
        query =
          Query.from(f in fragment("SELECT (? = ?) as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == Ratio.eq?(a, b)
      end
    end

    test "passes on non-simplified values" do
      a = {6, 3}
      b = {2, 1}

      query = Query.from(f in fragment("SELECT (?::rational = ?::rational) as r", ^a, ^b), select: f.r)

      result = Repo.one!(query)

      assert is_boolean(result)
      assert result
    end

    table_field_cases = [
      %{a: Ratio.new(1, 2), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(-1, 2), b: Ratio.new(1, 2), expected: false},
      %{a: Ratio.new(1, 2), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(-1, 2), b: Ratio.new(-1, 2), expected: true},
      %{a: Ratio.new(1, 4), b: Ratio.new(1, 2), expected: false},
      %{a: Ratio.new(-1, 4), b: Ratio.new(1, 2), expected: false},
      %{a: Ratio.new(1, 4), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(-1, 4), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(3, 4), b: Ratio.new(1, 2), expected: false},
      %{a: Ratio.new(-3, 4), b: Ratio.new(1, 2), expected: false},
      %{a: Ratio.new(3, 4), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(-3, 4), b: Ratio.new(-1, 2), expected: false}
    ]

    table_test "can be used in WHERE table.field | <%= a %> = <%= b %>", table_field_cases, test_case do
      run_table_comparison_test(test_case, fn query -> Query.where(query, [r], r.a == r.b) end)
    end
  end

  describe "Postgres != (not equals)" do
    property "matches Ratio using <> operator" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0, 1))))
            ) do
        query = Query.from(f in fragment("SELECT (? <> ?) as r", type(^a, PgRational), type(^b, PgRational)), select: f.r)
        result = Repo.one!(query)

        assert is_boolean(result)
        refute result == Ratio.eq?(a, b)
      end
    end

    property "matches Ratio using != operator" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0, 1))))
            ) do
        query =
          Query.from(
            f in fragment("SELECT (? != ?) as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        refute result == Ratio.eq?(a, b)
      end
    end

    table_field_cases = [
      %{a: Ratio.new(1, 2), b: Ratio.new(1, 2), expected: false},
      %{a: Ratio.new(-1, 2), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(1, 2), b: Ratio.new(-1, 2), expected: true},
      %{a: Ratio.new(-1, 2), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(1, 4), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(-1, 4), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(1, 4), b: Ratio.new(-1, 2), expected: true},
      %{a: Ratio.new(-1, 4), b: Ratio.new(-1, 2), expected: true},
      %{a: Ratio.new(3, 4), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(-3, 4), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(3, 4), b: Ratio.new(-1, 2), expected: true},
      %{a: Ratio.new(-3, 4), b: Ratio.new(-1, 2), expected: true}
    ]

    table_test "can be used in WHERE table.field | <%= a %> != <%= b %>", table_field_cases, test_case do
      run_table_comparison_test(test_case, fn query -> Query.where(query, [r], r.a != r.b) end)
    end
  end

  describe "Postgres < (less than)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0, 1))))
            ) do
        query =
          Query.from(f in fragment("SELECT (? < ?) as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == Ratio.lt?(a, b)
      end
    end

    table_field_cases = [
      %{a: Ratio.new(1, 2), b: Ratio.new(1, 2), expected: false},
      %{a: Ratio.new(-1, 2), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(1, 2), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(-1, 2), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(1, 4), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(-1, 4), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(1, 4), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(-1, 4), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(3, 4), b: Ratio.new(1, 2), expected: false},
      %{a: Ratio.new(-3, 4), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(3, 4), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(-3, 4), b: Ratio.new(-1, 2), expected: true}
    ]

    table_test "can be used in WHERE table.field | <%= a %> < <%= b %>", table_field_cases, test_case do
      run_table_comparison_test(test_case, fn query -> Query.where(query, [r], r.a < r.b) end)
    end
  end

  describe "Postgres <= (less than or equal to)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0, 1))))
            ) do
        query =
          Query.from(
            f in fragment("SELECT (? <= ?) as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == Ratio.lte?(a, b)
      end
    end

    table_field_cases = [
      %{a: Ratio.new(1, 2), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(-1, 2), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(1, 2), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(-1, 2), b: Ratio.new(-1, 2), expected: true},
      %{a: Ratio.new(1, 4), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(-1, 4), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(1, 4), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(-1, 4), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(3, 4), b: Ratio.new(1, 2), expected: false},
      %{a: Ratio.new(-3, 4), b: Ratio.new(1, 2), expected: true},
      %{a: Ratio.new(3, 4), b: Ratio.new(-1, 2), expected: false},
      %{a: Ratio.new(-3, 4), b: Ratio.new(-1, 2), expected: true}
    ]

    table_test "can be used in WHERE table.field | <%= a %> <= <%= b %>", table_field_cases, test_case do
      run_table_comparison_test(test_case, fn query -> Query.where(query, [r], r.a <= r.b) end)
    end
  end

  describe "Postgres > (greater than)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0, 1))))
            ) do
        query =
          Query.from(f in fragment("SELECT (? > ?) as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == Ratio.gt?(a, b)
      end
    end

    test "can be used on table fields | equal" do
      assert {:ok, %{id: _record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(1, 2), b: Ratio.new(1, 2)})
               |> Repo.insert()

      result =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.a > r.b)
        |> Repo.one()

      assert is_nil(result)
    end

    test "can be used on table fields | less than" do
      assert {:ok, %{id: _record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(1, 4), b: Ratio.new(1, 2)})
               |> Repo.insert()

      result =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.a > r.b)
        |> Repo.one()

      assert is_nil(result)
    end

    test "can be used on table fields | greater than" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(1, 2), b: Ratio.new(1, 4)})
               |> Repo.insert()

      result =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.a > r.b)
        |> Repo.one()

      assert result == record_id
    end
  end

  describe "Postgres >= (greater than or equal to)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0, 1))))
            ) do
        query =
          Query.from(
            f in fragment("SELECT (? >= ?) as r", type(^a, PgRational), type(^b, PgRational)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == Ratio.gte?(a, b)
      end
    end

    test "can be used on table fields | equal" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(1, 2), b: Ratio.new(1, 2)})
               |> Repo.insert()

      result =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.a >= r.b)
        |> Repo.one()

      assert result == record_id
    end

    test "can be used on table fields | less than" do
      assert {:ok, %{id: _record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(1, 4), b: Ratio.new(1, 2)})
               |> Repo.insert()

      result =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.a >= r.b)
        |> Repo.one()

      assert is_nil(result)
    end

    test "can be used on table fields | greater than" do
      assert {:ok, %{id: record_id}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(1, 2), b: Ratio.new(1, 4)})
               |> Repo.insert()

      result =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.a >= r.b)
        |> Repo.one()

      assert result == record_id
    end
  end

  describe "Postgres CAST AS double precision" do
    property "matches application code value" do
      check all(rational <- StreamDataVtc.rational()) do
        query =
          Query.from(f in fragment("SELECT CAST (? AS double precision) as r", type(^rational, PgRational)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_float(result)
        assert result == rational.numerator / rational.denominator
      end
    end
  end

  @spec run_table_comparison_test(
          %{a: Ratio.t(), b: Ratio.t(), expected: boolean()},
          (Queryable.t() -> Query.t())
        ) :: term()
  defp run_table_comparison_test(test_case, where_filter) do
    %{a: a, b: b, expected: expected} = test_case

    assert {:ok, %{id: record_id}} =
             %RationalsSchema02{}
             |> RationalsSchema02.changeset(%{a: a, b: b})
             |> Repo.insert()

    result =
      RationalsSchema02
      |> Query.select([r], r.id)
      |> where_filter.()
      |> Repo.one()

    if expected do
      assert result == record_id
    else
      assert is_nil(result)
    end
  end
end
