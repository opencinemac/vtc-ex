defmodule Vtc.Ecto.Postgres.PgFramerateTest do
  use Vtc.Test.Support.EctoCase, async: true
  use ExUnitProperties

  alias Ecto.Changeset
  alias Ecto.Query
  alias Vtc.Framerate
  alias Vtc.Rates
  alias Vtc.Test.Support.FramerateSchema01
  alias Vtc.TestUtls.StreamDataVtc

  require Query

  describe "#cast/1" do
    cast_table = [
      %{
        name: "%Framerate{} struct",
        input: Rates.f23_98(),
        expected: Rates.f23_98()
      },
      %{
        name: "map with playback string",
        input: %{playback: "24/1"},
        expected: Rates.f24()
      },
      %{
        name: "map with playback array",
        input: %{playback: [24, 1]},
        expected: Rates.f24()
      },
      %{
        name: "map with playback Ratio",
        input: %{playback: Ratio.new(24)},
        expected: Rates.f24()
      },
      %{
        name: "map with ntsc: 'drop'",
        input: %{playback: "30000/1001", ntsc: "drop"},
        expected: Rates.f29_97_df()
      },
      %{
        name: "map with ntsc: 'non_drop'",
        input: %{playback: "24000/1001", ntsc: "non_drop"},
        expected: Rates.f23_98()
      },
      %{
        name: "map with ntsc: :drop",
        input: %{playback: "30000/1001", ntsc: :drop},
        expected: Rates.f29_97_df()
      },
      %{
        name: "map with ntsc: :non_drop",
        input: %{playback: "24000/1001", ntsc: :non_drop},
        expected: Rates.f23_98()
      },
      %{
        name: "map with ntsc: `nil`",
        input: %{playback: "24/1", ntsc: nil},
        expected: Rates.f24()
      }
    ]

    table_test "<%= name %>", cast_table, test_case do
      %{input: input, expected: expected} = test_case
      assert {:ok, result} = Framerate.cast(input)
      assert result == expected
    end

    table_test "<%= name %> | string keys", cast_table, test_case,
      if: is_map(test_case.input) and not is_struct(test_case.input) do
      %{input: input, expected: expected} = test_case
      input = input |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end) |> Map.new()

      assert {:ok, result} = Framerate.cast(input)
      assert result == expected
    end

    property "succeeds with `:playback` string" do
      check all(framerate <- StreamDataVtc.framerate()) do
        input = %{
          playback: "#{framerate.playback.numerator}/#{framerate.playback.denominator}",
          ntsc: framerate.ntsc
        }

        assert {:ok, result} = Framerate.cast(input)
        assert result == framerate
      end
    end

    property "succeeds with `:playback` array" do
      check all(framerate <- StreamDataVtc.framerate()) do
        input = %{
          playback: [framerate.playback.numerator, framerate.playback.denominator],
          ntsc: framerate.ntsc
        }

        assert {:ok, result} = Framerate.cast(input)
        assert result == framerate
      end
    end

    table_test "succeeds in changesets | <%= name %>", cast_table, test_case do
      %{input: input, expected: expected} = test_case

      attrs = %{a: input, b: input}

      assert {:ok, result} = %FramerateSchema01{} |> FramerateSchema01.changeset(attrs) |> Changeset.apply_action(:test)
      assert %FramerateSchema01{} = result
      assert result.a == expected
      assert result.b == expected
    end

    table_test "succeeds in changesets | <%= name %> | string keys", cast_table, test_case,
      if: is_map(test_case.input) and not is_struct(test_case.input) do
      %{input: input, expected: expected} = test_case

      input = input |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end) |> Map.new()
      attrs = %{a: input, b: input}

      assert {:ok, result} = %FramerateSchema01{} |> FramerateSchema01.changeset(attrs) |> Changeset.apply_action(:test)
      assert %FramerateSchema01{} = result
      assert result.a == expected
      assert result.b == expected
    end

    cast_error_table = [
      %{
        name: "bad non_drop rate",
        input: %{playback: [24_000, 1002], ntsc: :non_drop}
      },
      %{
        name: "bad drop rate",
        input: %{playback: [24_000, 1001], ntsc: :drop}
      },
      %{
        name: "negative non_drop",
        input: %{playback: [-24_000, 1001], ntsc: :non_drop}
      },
      %{
        name: "negative drop",
        input: %{playback: [-30_000, 1001], ntsc: :drop}
      },
      %{
        name: "negative true",
        input: %{playback: [-24, 1], ntsc: :drop}
      },
      %{
        name: ":playback integer",
        input: %{playback: 24, ntsc: nil}
      },
      %{
        name: ":playback float",
        input: %{playback: 24.0, ntsc: nil}
      }
    ]

    table_test "errors on <%= name %>", cast_error_table, test_case do
      %{input: input} = test_case

      assert :error = Framerate.cast(input)
    end

    table_test "errors on <%= name %> in changesets", cast_error_table, test_case do
      %{input: input} = test_case

      attrs = %{a: input, b: input}

      assert %Changeset{valid?: false, errors: errors} = FramerateSchema01.changeset(%FramerateSchema01{}, attrs)
      assert {:a, {"is invalid", [type: Framerate, validation: :cast]}} in errors
      assert {:b, {"is invalid", [type: Framerate, validation: :cast]}} in errors
    end
  end

  serialization_table = [
    %{
      application_value: Rates.f23_98(),
      database_record: {{24_000, 1001}, ["non_drop"]}
    },
    %{
      application_value: Rates.f29_97_df(),
      database_record: {{30_000, 1001}, ["drop"]}
    },
    %{
      application_value: Rates.f24(),
      database_record: {{24, 1}, []}
    },
    %{
      application_value: Framerate.new!(Ratio.new(24_000, 1001), ntsc: nil),
      database_record: {{24_000, 1001}, []}
    }
  ]

  describe "#dump/1" do
    table_test "succeeds on <%= application_value %>", serialization_table, test_case do
      %{application_value: application_value, database_record: database_record} = test_case

      assert {:ok, result} = Framerate.dump(application_value)
      assert result == database_record
    end

    property "succeeds on good framerate" do
      check all(framerate <- StreamDataVtc.framerate()) do
        assert {:ok, result} = Framerate.dump(framerate)
        chack_dumped(result, framerate)
      end
    end
  end

  @spec chack_dumped(Framerate.db_record(), Framerate.t()) :: term()
  defp chack_dumped(result, input) do
    assert {{numerator, denominator}, tags} = result
    assert numerator == input.playback.numerator
    assert denominator == input.playback.denominator
    assert is_list(tags)

    case input.ntsc do
      :drop -> assert "drop" in tags
      :non_drop -> assert "non_drop" in tags
      nil -> assert "drop" not in tags and "non_drop" not in tags
    end
  end

  describe "#load/1" do
    table_test "<%= application_value %>", serialization_table, test_case do
      %{application_value: application_value, database_record: database_record} = test_case

      assert {:ok, result} = Framerate.load(database_record)
      assert result == application_value
    end
  end

  property "round trip dump/1 -> load/1" do
    check all(framerate <- StreamDataVtc.framerate()) do
      assert {:ok, dumped} = Framerate.dump(framerate)
      assert {:ok, ^framerate} = Framerate.load(dumped)
    end
  end

  describe "#SELECT" do
    basic_query_table = [
      %{
        raw_sql: "((24, 1), '{}')",
        expected: {{24, 1}, []}
      },
      %{
        raw_sql: "((24000, 1001), '{non_drop}')",
        expected: {{24_000, 1001}, ["non_drop"]}
      },
      %{
        raw_sql: "((30000, 1001), '{drop}')",
        expected: {{30_000, 1001}, ["drop"]}
      }
    ]

    table_test "literal | <%= raw_sql %>", basic_query_table, test_case do
      %{raw_sql: raw_sql, expected: expected} = test_case
      assert %Postgrex.Result{rows: [[db_record]]} = Repo.query!("SELECT #{raw_sql}::framerate")
      assert db_record == expected
    end

    table_test "placeholder | <%= application_value %>", serialization_table, test_case do
      %{application_value: application_value, database_record: database_record} = test_case

      query = Query.from(f in fragment("SELECT ? as r", type(^application_value, Framerate)), select: f.r)
      assert Repo.one!(query) == database_record
    end

    table_test "playback field | <%= application_value %>", serialization_table, test_case do
      %{database_record: {expected, _}, application_value: application_value} = test_case

      query = Query.from(f in fragment("SELECT (?).playback as r", type(^application_value, Framerate)), select: f.r)
      assert Repo.one!(query) == expected
    end

    table_test "tags field | <%= application_value %>", serialization_table, test_case do
      %{database_record: {_, expected}, application_value: application_value} = test_case

      query = Query.from(f in fragment("SELECT (?).tags as r", type(^application_value, Framerate)), select: f.r)
      assert Repo.one!(query) == expected
    end

    property "succeeds on good framerate" do
      check all(framerate <- StreamDataVtc.framerate()) do
        query = Query.from(f in fragment("SELECT ? as r", type(^framerate, Framerate)), select: f.r)
        assert record = Repo.one!(query)
        assert {:ok, ^framerate} = Framerate.load(record)
      end
    end
  end

  describe "#table serialization" do
    table_test "can insert into field without constraints", serialization_table, test_case do
      %{application_value: application_value} = test_case

      assert {:ok, inserted} =
               %FramerateSchema01{}
               |> FramerateSchema01.changeset(%{a: application_value})
               |> Repo.insert()

      assert %FramerateSchema01{} = inserted
      assert inserted.a == application_value
      assert inserted.b == nil

      assert %FramerateSchema01{} = record = Repo.get(FramerateSchema01, inserted.id)
      assert record.a == application_value
      assert record.b == nil
    end

    table_test "can insert into field with constraints", serialization_table, test_case do
      %{application_value: application_value} = test_case

      assert {:ok, inserted} =
               %FramerateSchema01{}
               |> FramerateSchema01.changeset(%{b: application_value})
               |> Repo.insert()

      assert %FramerateSchema01{} = inserted
      assert inserted.a == nil
      assert inserted.b == application_value

      assert %FramerateSchema01{} = record = Repo.get(FramerateSchema01, inserted.id)
      assert record.a == nil
      assert record.b == application_value
    end

    property "succeeds on good framerate" do
      check all(framerate <- StreamDataVtc.framerate()) do
        assert {:ok, inserted} =
                 %FramerateSchema01{}
                 |> FramerateSchema01.changeset(%{a: framerate, b: framerate})
                 |> Repo.insert()

        assert %FramerateSchema01{} = inserted
        assert inserted.a == framerate
        assert inserted.b == framerate

        assert %FramerateSchema01{} = record = Repo.get(FramerateSchema01, inserted.id)
        assert record.a == framerate
        assert record.b == framerate
      end
    end

    bad_insert_table = [
      %{
        name: "negative",
        value: "((-24000, 1001), '{non_drop}')",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "zero",
        value: "((0, 1001), '{non_drop}')",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "zero denominator",
        value: "((24, 0), '{}')",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "negative denominator",
        value: "((24, -1), '{}')",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "bad tag with constraints",
        value: "((24000, 1001), '{bad_tag}')",
        field: :b,
        expected_code: :invalid_text_representation
      },
      %{
        name: "bad tag without constraints",
        value: "((24000, 1001), '{bad_tag}')",
        field: :a,
        expected_code: :invalid_text_representation
      },
      %{
        name: "multiple ntsc tags",
        value: "((30000, 1001), '{drop, non_drop}')",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_ntsc_tags"
      },
      %{
        name: "bad ntsc rate",
        value: "((24, 1), '{non_drop}')",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_ntsc_valid"
      },
      %{
        name: "bad drop rate",
        value: "((24000, 1001), '{drop}')",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_ntsc_drop_valid"
      }
    ]

    table_test "error <%= name %>", bad_insert_table, test_case do
      %{value: value, expected_code: expected_code, field: field} = test_case

      value_str = "#{value}::framerate"
      {a, b} = if field == :a, do: {value_str, "NULL"}, else: {"NULL", value_str}

      id = Ecto.UUID.generate()
      query = "INSERT INTO framerates_01 (id, a, b) VALUES ('#{id}', #{a}, #{b})"

      assert {:error, error} = Repo.query(query)
      assert %Postgrex.Error{postgres: %{code: ^expected_code} = postgres} = error

      if expected_code == :check_violation do
        assert postgres.constraint == test_case.expected_constraint
      end
    end
  end

  describe "Postgres framerate.is_ntsc/1" do
    is_ntsc_table = [
      %{input: Rates.f23_98(), expected: true},
      %{input: Rates.f24(), expected: false},
      %{input: Rates.f59_94_df(), expected: true},
      %{input: Rates.f59_94_ndf(), expected: true}
    ]

    table_test "<%= input %> | <%= expected %>", is_ntsc_table, test_case do
      %{input: input, expected: expected} = test_case

      query = Query.from(f in fragment("SELECT framerate.is_ntsc(?) as r", type(^input, Framerate)), select: f.r)
      result = Repo.one(query)

      assert is_boolean(result)
      assert result == expected
    end

    property "matches Framerate.ntsc?/1" do
      check all(framerate <- StreamDataVtc.framerate()) do
        query = Query.from(f in fragment("SELECT framerate.is_ntsc(?) as r", type(^framerate, Framerate)), select: f.r)
        result = Repo.one(query)

        assert is_boolean(result)
        assert result == Framerate.ntsc?(framerate)
      end
    end
  end

  strict_eq_table = [
    %{a: Rates.f23_98(), b: Rates.f23_98(), expected: true},
    %{a: Rates.f23_98(), b: Rates.f24(), expected: false},
    %{a: Rates.f23_98(), b: Framerate.new!(Ratio.new(24_000, 1001), ntsc: nil), expected: false},
    %{a: Rates.f24(), b: Rates.f24(), expected: true},
    %{a: Rates.f59_94_ndf(), b: Rates.f59_94_ndf(), expected: true},
    %{a: Rates.f59_94_df(), b: Rates.f59_94_df(), expected: true},
    %{a: Rates.f59_94_ndf(), b: Rates.f59_94_df(), expected: false},
    %{a: Rates.f59_94_df(), b: Framerate.new!(Ratio.new(60_000, 1001), ntsc: nil), expected: false}
  ]

  describe "Postgres === (strict equality)" do
    table_test "<%= a %> === <%= b %> | <%= expected %>", strict_eq_table, test_case do
      %{a: a, b: b, expected: expected} = test_case

      query = Query.from(f in fragment("SELECT ? === ? as r", type(^a, Framerate), type(^b, Framerate)), select: f.r)
      result = Repo.one(query)

      assert is_boolean(result)
      assert result == expected
    end

    property "matches a == b" do
      check all(
              a <- StreamDataVtc.framerate(),
              b <- StreamDataVtc.framerate()
            ) do
        query = Query.from(f in fragment("SELECT ? === ? as r", type(^a, Framerate), type(^b, Framerate)), select: f.r)
        result = Repo.one(query)

        assert is_boolean(result)
        assert result == (a == b)
      end
    end
  end

  describe "Postgres === (strict not equality)" do
    table_test "<%= a %> !=== <%= b %> | <%= expected %>", strict_eq_table, test_case do
      %{a: a, b: b, expected: expected} = test_case

      query = Query.from(f in fragment("SELECT ? !=== ? as r", type(^a, Framerate), type(^b, Framerate)), select: f.r)
      result = Repo.one(query)

      assert is_boolean(result)
      refute result == expected
    end

    property "matches a != b" do
      check all(
              a <- StreamDataVtc.framerate(),
              b <- StreamDataVtc.framerate()
            ) do
        query = Query.from(f in fragment("SELECT ? !=== ? as r", type(^a, Framerate), type(^b, Framerate)), select: f.r)
        result = Repo.one(query)

        assert is_boolean(result)
        assert result == (a != b)
      end
    end
  end
end
