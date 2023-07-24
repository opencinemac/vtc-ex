defmodule Vtc.Ecto.Postgres.PgRationalTest do
  use Vtc.Test.Support.EctoCase, async: true
  use ExUnitProperties

  alias Ecto.Query
  alias Ecto.Repo.Queryable
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Test.Support.RationalsSchema01
  alias Vtc.Test.Support.RationalsSchema02
  alias Vtc.TestUtils.StreamDataVtc
  alias Vtc.Utils.Rational

  require Ecto.Query
  require PgRational

  @spec run_select_test(String.t(), [Macro.t()], Macro.t()) :: Macro.t()
  defmacrop run_select_test(sql_query, arguments, expected) do
    sql_query = "SELECT #{sql_query} as result"
    arguments = with arguments when not is_list(arguments) <- arguments, do: [arguments]

    quote do
      Query.from(f in fragment(unquote(sql_query), unquote_splicing(arguments)), select: f.result)
      |> Repo.one!()
      |> check_result(unquote(expected))
    end
  end

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
        assert {:ok, record} = insert_record(a, b)

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
        assert {:ok, record} = insert_record(a, b, RationalsSchema02)

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

  describe "Postgres unary - (negate)" do
    property "matches Ratio" do
      check all(input <- StreamDataVtc.rational()) do
        expected = Ratio.minus(input)
        run_select_test("-?", type(^input, PgRational), expected)
      end
    end

    test "can be used on table fields" do
      expected = Ratio.new(-3, 4)

      run_schema_test(Ratio.new(3, 4), Ratio.new(1), expected, fn query ->
        Query.select(query, [r], fragment("-?", r.a))
      end)
    end
  end

  describe "Postgres ABS/1" do
    property "matches Ratio" do
      check all(input <- StreamDataVtc.rational()) do
        expected = Ratio.abs(input)
        run_select_test("ABS(?)", type(^input, PgRational), expected)
      end
    end

    property "matches Ratio | @ operator" do
      check all(input <- StreamDataVtc.rational()) do
        expected = Ratio.abs(input)
        run_select_test("@?", type(^input, PgRational), expected)
      end
    end

    abs_table = [
      %{a: Ratio.new(-3, 4), expected: Ratio.new(3, 4)},
      %{a: Ratio.new(3, 4), expected: Ratio.new(3, 4)}
    ]

    table_test "can be used on table fields | <%= a %>", abs_table, test_case do
      %{a: a, expected: expected} = test_case

      run_schema_test(a, Ratio.new(1), expected, fn query ->
        Query.select(query, [r], fragment("ABS(?)", r.a))
      end)
    end

    table_test "can be used on table fields | <%= a %> | @ operator", abs_table, test_case do
      %{a: a, expected: expected} = test_case

      run_schema_test(a, Ratio.new(1), expected, fn query ->
        Query.select(query, [r], fragment("@?", r.a))
      end)
    end
  end

  describe "Postgres SIGN/1" do
    property "can be selected" do
      check all(input <- StreamDataVtc.rational()) do
        expected =
          case Ratio.compare(input, Ratio.new(0)) do
            :lt -> -1
            :eq -> 0
            :gt -> 1
          end

        run_select_test("SIGN(?)", type(^input, PgRational), expected)
      end
    end

    sign_table = [
      %{a: Ratio.new(-3, 4), expected: -1},
      %{a: Ratio.new(0), expected: 0},
      %{a: Ratio.new(3, 4), expected: 1}
    ]

    table_test "can be used on table fields | <%= a %>", sign_table, test_case do
      %{a: a, expected: expected} = test_case

      run_schema_test(a, Ratio.new(1), expected, fn query ->
        Query.select(query, [r], fragment("SIGN(?)", r.a))
      end)
    end
  end

  describe "Postgres ROUND/1" do
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
      run_select_test("ROUND(?)", type(^input, PgRational), expected)
    end

    property "matches Ratio" do
      check all(input <- StreamDataVtc.rational()) do
        expected = Rational.round(input)
        run_select_test("ROUND(?)", type(^input, PgRational), expected)
      end
    end

    property "can be used on table fields" do
      check all(a <- StreamDataVtc.rational()) do
        expected = Rational.round(a)

        run_schema_test(a, Ratio.new(1), expected, fn query ->
          Query.select(query, [r], fragment("ROUND(?)", r.a))
        end)
      end
    end
  end

  describe "Postgres FLOOR/1" do
    round_table = [
      %{input: Ratio.new(1), expected: 1},
      %{input: Ratio.new(-1), expected: -1},
      %{input: Ratio.new(1, 2), expected: 0},
      %{input: Ratio.new(-1, 2), expected: 0},
      %{input: Ratio.new(1, 4), expected: 0},
      %{input: Ratio.new(-1, 4), expected: 0},
      %{input: Ratio.new(3, 4), expected: 0},
      %{input: Ratio.new(-3, 4), expected: 0}
    ]

    table_test "<%= input %> = <%= expected %>", round_table, test_case do
      %{input: input, expected: expected} = test_case
      run_select_test("FLOOR(?)", type(^input, PgRational), expected)
    end

    property "matches Ratio.trunc/1" do
      check all(input <- StreamDataVtc.rational()) do
        expected = Ratio.trunc(input)
        run_select_test("FLOOR(?)", type(^input, PgRational), expected)
      end
    end

    property "can be used on table fields" do
      check all(a <- StreamDataVtc.rational()) do
        expected = Ratio.trunc(a)

        run_schema_test(a, Ratio.new(1), expected, fn query ->
          Query.select(query, [r], fragment("FLOOR(?)", r.a))
        end)
      end
    end
  end

  describe "Postgres + (add)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        expected = Ratio.add(a, b)
        run_select_test("? + ?", [type(^a, PgRational), type(^b, PgRational)], expected)
      end
    end

    property "can be used on table fields" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        expected = Ratio.add(a, b)

        run_schema_test(a, b, expected, fn query ->
          Query.select(query, [r], r.a + r.b)
        end)
      end
    end
  end

  describe "Postgres - (subtract)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        expected = Ratio.sub(a, b)
        run_select_test("? - ?", [type(^a, PgRational), type(^b, PgRational)], expected)
      end
    end

    property "can be used on table fields" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        expected = Ratio.sub(a, b)

        run_schema_test(a, b, expected, fn query ->
          Query.select(query, [r], r.a - r.b)
        end)
      end
    end
  end

  describe "Postgres * (multiply)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        expected = Ratio.mult(a, b)
        run_select_test("? * ?", [type(^a, PgRational), type(^b, PgRational)], expected)
      end
    end

    property "can be used on table fields" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamDataVtc.rational()
            ) do
        expected = Ratio.mult(a, b)

        run_schema_test(a, b, expected, fn query ->
          Query.select(query, [r], r.a * r.b)
        end)
      end
    end
  end

  describe "Postgres DIV/1 (floor divide)" do
    test "expected result" do
      expected = 3

      run_schema_test(Ratio.new(23, 8), Ratio.new(4, 5), expected, fn query ->
        Query.select(query, [r], fragment("DIV(?, ?)", r.a, r.b))
      end)
    end

    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
            ) do
        expected = a |> Ratio.div(b) |> Ratio.trunc()
        run_select_test("DIV(?, ?)", [type(^a, PgRational), type(^b, PgRational)], expected)
      end
    end

    property "can be used on table fields" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
            ) do
        expected = a |> Ratio.div(b) |> Ratio.trunc()

        run_schema_test(a, b, expected, fn query ->
          Query.select(query, [r], fragment("DIV(?, ?)", r.a, r.b))
        end)
      end
    end
  end

  describe "Postgres / (divide)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
            ) do
        expected = Ratio.div(a, b)
        run_select_test("? / ?", [type(^a, PgRational), type(^b, PgRational)], expected)
      end
    end

    test "can be used on table fields" do
      expected = Ratio.new(115, 32)

      run_schema_test(Ratio.new(23, 8), Ratio.new(4, 5), expected, fn query ->
        Query.select(query, [r], r.a / r.b)
      end)
    end

    property "table fields" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
            ) do
        expected = Ratio.div(a, b)

        run_schema_test(a, b, expected, fn query ->
          Query.select(query, [r], r.a / r.b)
        end)
      end
    end
  end

  describe "Postgres % (modulo)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
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
      result =
        run_schema_arithmetic_test(Ratio.new(23, 8), Ratio.new(4, 5), fn query ->
          Query.select(query, [r], fragment("? % ?", r.a, r.b))
        end)

      expected = Rational.rem(Ratio.new(23, 8), Ratio.new(4, 5))
      assert result == expected
    end

    property "table fields" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
            ) do
        result =
          run_schema_arithmetic_test(a, b, fn query ->
            Query.select(query, [r], fragment("? % ?", r.a, r.b))
          end)

        assert result == Rational.rem(a, b)
      end
    end
  end

  describe "Postgres rational.__private__comp/2" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
            ) do
        query =
          Query.from(
            f in fragment(
              "SELECT rational.__private__cmp(?, ?) as r",
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
               |> Query.select([r], fragment("rational.__private__cmp(?, ?)", r.a, r.b))
               |> Query.where([r], r.id == ^record_id)
               |> Repo.one!()

      assert result == 1
    end
  end

  describe "Postgres = (equals)" do
    property "matches Ratio" do
      check all(
              a <- StreamDataVtc.rational(),
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
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
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
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
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
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
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
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
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
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
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
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
              b <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, Ratio.new(0))))
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

    assert {:ok, %{id: record_id}} = insert_record(a, b, RationalsSchema02)

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

  # Runs a test that inserts a records and then queries for that record, returning
  # the result of `select`.
  @spec run_schema_arithmetic_test(Ratio.t(), Ratio.t(), (Queryable.t() -> Query.t())) :: Ratio.t() | integer()
  defp run_schema_arithmetic_test(a, b, select) do
    assert {:ok, %{id: record_id}} =
             %RationalsSchema02{}
             |> RationalsSchema02.changeset(%{a: a, b: b})
             |> Repo.insert()

    assert {:ok, result} =
             RationalsSchema02
             |> select.()
             |> Query.where([r], r.id == ^record_id)
             |> Repo.one!()
             |> then(fn
               {_, _} = result -> PgRational.load(result)
               result -> {:ok, result}
             end)

    refute is_nil(result)

    result
  end

  @typep insert_attr() :: Ratio.t() | nil

  @spec insert_record(insert_attr(), insert_attr(), RationalsSchema01) :: {:ok, RationalsSchema01.t()}
  @spec insert_record(insert_attr(), insert_attr(), RationalsSchema02) :: {:ok, RationalsSchema02.t()}
  defp insert_record(a, b, schema \\ RationalsSchema01) do
    case insert_records([{a, b}], schema) do
      {:ok, [record]} -> {:ok, record}
      {:error, _} = result -> result
    end
  end

  @spec insert_records([{insert_attr(), insert_attr()}], RationalsSchema01) :: {:ok, [RationalsSchema01.t()]}
  @spec insert_records([{insert_attr(), insert_attr()}], RationalsSchema02) :: {:ok, [RationalsSchema02.t()]}
  defp insert_records(attrs_list, schema) do
    attrs_list
    |> Enum.map(fn {a, b} -> %{a: a, b: b} end)
    |> Enum.map(fn attrs ->
      attrs
      |> Map.put_new(:a, nil)
      |> Map.put_new(:b, nil)
      |> then(&schema.changeset(struct(schema), &1))
      |> Repo.insert()
    end)
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, []}, fn result, {:ok, records} ->
      case result do
        {:ok, record} -> {:cont, {:ok, [record | records]}}
        {:error, _} = result -> {:halt, result}
      end
    end)
  end

  # Runs a test where a value is extracted from a schema.
  @spec run_schema_test(
          insert_attr(),
          insert_attr(),
          expected,
          RationalsSchema01 | RationalsSchema02,
          (Queryable.t() -> Query.t())
        ) :: expected
        when expected: any()
  defp run_schema_test(a, b, expected, schema \\ RationalsSchema01, select_query) do
    assert {:ok, %{id: record_id}} = insert_record(a, b, schema)

    schema
    |> select_query.()
    |> Query.where([r], r.id == ^record_id)
    |> Repo.one!()
    |> check_result(expected)
  end

  # Checks the results of a query. Loads rational value AND checks raw record results
  # if rational is expected to be returned.
  @spec check_result(any(), expected_type) :: expected_type when expected_type: any()
  defp check_result(result, %Ratio{} = expected) do
    assert {numerator, denominator} = result

    assert {:ok, loaded} = PgRational.load(result)
    assert loaded == expected

    assert numerator == expected.numerator
    assert denominator == expected.denominator

    loaded
  end

  defp check_result(result, expected) do
    assert result == expected

    result
  end
end
