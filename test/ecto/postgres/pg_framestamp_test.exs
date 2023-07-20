defmodule Vtc.Ecto.Postgres.PgFramestampTest do
  use Vtc.Test.Support.EctoCase, async: true
  use ExUnitProperties

  alias Ecto.Changeset
  alias Ecto.Query
  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Rates
  alias Vtc.Test.Support.CommonTables
  alias Vtc.Test.Support.FramestampSchema01
  alias Vtc.Test.Support.TestCase
  alias Vtc.TestUtils.StreamDataVtc

  require Query

  doctest Vtc.Ecto.Postgres.PgFramestamp.Migrations

  describe "#cast/1" do
    cast_table = [
      %{
        input: Framestamp.with_frames!("01:00:00:00", Rates.f23_98()),
        expected: Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      },
      %{
        input: %{
          smpte_timecode: "01:00:00:00",
          rate: %{
            playback: [24_000, 1001],
            ntsc: :non_drop
          }
        },
        expected: Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      },
      %{
        input: %{
          smpte_timecode: "-01:00:00:00",
          rate: %{
            playback: "24000/1001",
            ntsc: :non_drop
          }
        },
        expected: Framestamp.with_frames!("-01:00:00:00", Rates.f23_98())
      },
      %{
        input: %{
          smpte_timecode: "01:00:00:00",
          rate: %{
            playback: [30_000, 1001],
            ntsc: :drop
          }
        },
        expected: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_df())
      },
      %{
        input: %{
          smpte_timecode: "-01:00:00:00",
          rate: %{
            playback: [30_000, 1001],
            ntsc: :drop
          }
        },
        expected: Framestamp.with_frames!("-01:00:00:00", Rates.f29_97_df())
      },
      %{
        input: %{
          smpte_timecode: "01:00:00:00",
          rate: %{
            playback: [30_000, 1001],
            ntsc: "non_drop"
          }
        },
        expected: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_ndf())
      }
    ]

    table_test "<%= expected %>", cast_table, test_case do
      %{input: input, expected: expected} = test_case
      assert {:ok, ^expected} = Framestamp.cast(input)
    end

    table_test "<%= expected %> | string keys", cast_table, test_case do
      %{input: input, expected: expected} = test_case
      input = convert_input_to_string_keys(input)

      assert {:ok, ^expected} = Framestamp.cast(input)
    end

    table_test "<%= expected %> | through changeset", cast_table, test_case do
      %{input: input, expected: expected} = test_case

      assert {:ok, record} =
               %FramestampSchema01{}
               |> FramestampSchema01.changeset(%{a: input, b: input})
               |> Changeset.apply_action(:test)

      assert record.a == expected
      assert record.b == expected
    end

    table_test "<%= expected %> | through changeset | string keys", cast_table, test_case do
      %{input: input, expected: expected} = test_case
      input = convert_input_to_string_keys(input)

      assert {:ok, record} =
               %FramestampSchema01{}
               |> FramestampSchema01.changeset(%{a: input, b: input})
               |> Changeset.apply_action(:test)

      assert record.a == expected
      assert record.b == expected
    end

    # Converts the input for a test cast from atom keys to string keys
    @spec convert_input_to_string_keys(%{atom() => any()}) :: %{String.t() => any()}
    defp convert_input_to_string_keys(%Framestamp{} = framestamp), do: framestamp

    defp convert_input_to_string_keys(input) do
      input =
        Map.update(input, :rate, %{}, fn rate_map ->
          rate_map |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end) |> Map.new()
        end)

      input |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end) |> Map.new()
    end

    bad_cast_table = [
      %{
        name: "feet+frames",
        input: %{
          smpte_timecode: "01+04",
          rate: %{
            playback: [24_000, 1001],
            ntsc: :non_drop
          }
        }
      },
      %{
        name: "frames integer",
        input: %{
          smpte_timecode: 24,
          rate: %{
            playback: [24_000, 1001],
            ntsc: :non_drop
          }
        }
      },
      %{
        name: "float",
        input: %{
          smpte_timecode: 24.0,
          rate: %{
            playback: [24_000, 1001],
            ntsc: :non_drop
          }
        }
      },
      %{
        name: "ratio",
        input: %{
          smpte_timecode: Ratio.new(24),
          rate: %{
            playback: [24_000, 1001],
            ntsc: :non_drop
          }
        }
      },
      %{
        name: "bad framerate",
        input: %{
          smpte_timecode: "01:00:00:00",
          rate: %{
            playback: [30_000, 1002],
            ntsc: :drop
          }
        }
      }
    ]

    table_test "fails on <%= name %>", bad_cast_table, test_case do
      %{input: input} = test_case
      assert :error = Framestamp.cast(input)
    end

    property "succeeds on good framestamp json" do
      check all(framestamp <- StreamDataVtc.framestamp(rate_opts: [type: [:whole, :drop, :non_drop]])) do
        input = %{
          smpte_timecode: Framestamp.smpte_timecode(framestamp),
          rate: %{
            playback: [framestamp.rate.playback.numerator, framestamp.rate.playback.denominator],
            ntsc: framestamp.rate.ntsc
          }
        }

        timecode_str = Framestamp.smpte_timecode(framestamp)
        assert {:ok, parsed} = Framestamp.with_frames(timecode_str, framestamp.rate)
        assert parsed == framestamp

        assert {:ok, result} = Framestamp.cast(input)
        assert result == framestamp
      end
    end
  end

  serialization_table = [
    %{
      app_value: Framestamp.with_frames!("01:00:00:00", Rates.f23_98()),
      db_value: {18_018, 5, 24_000, 1001, ["non_drop"]}
    },
    %{
      app_value: Framestamp.with_frames!("-01:00:00:00", Rates.f23_98()),
      db_value: {-18_018, 5, 24_000, 1001, ["non_drop"]}
    },
    %{
      app_value: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_df()),
      db_value: {8_999_991, 2500, 30_000, 1001, ["drop"]}
    },
    %{
      app_value: Framestamp.with_frames!("-01:00:00:00", Rates.f29_97_df()),
      db_value: {-8_999_991, 2500, 30_000, 1001, ["drop"]}
    },
    %{
      app_value: Framestamp.with_frames!("01:00:00:00", Rates.f24()),
      db_value: {3600, 1, 24, 1, []}
    },
    %{
      app_value: Framestamp.with_frames!("-01:00:00:00", Rates.f24()),
      db_value: {-3600, 1, 24, 1, []}
    }
  ]

  describe "#dump/1" do
    table_test "succeeds on <%= app_value %>", serialization_table, test_case do
      %{db_value: db_value, app_value: app_value} = test_case
      assert {:ok, ^db_value} = Framestamp.dump(app_value)
    end

    bad_dump_table = [
      %{input: "01:00:00:00"},
      %{input: Ratio.new(3600)},
      %{input: {"01:00:00:00", Rates.f23_98()}},
      %{input: {{-3600, 1}, {{24, 1}, []}}}
    ]

    table_test "fails on <%= input %>", bad_dump_table, test_case do
      %{input: input} = test_case
      assert :error = Framestamp.dump(input)
    end
  end

  describe "#load/1" do
    table_test "succeeds on <%= app_value %>", serialization_table, test_case do
      %{db_value: db_value, app_value: app_value} = test_case
      assert {:ok, ^app_value} = Framestamp.load(db_value)
    end

    bad_load_table = [
      %{name: "bad drop framerate", input: {{8_999_991, 2500}, {{30_000, 1002}, ["drop"]}}},
      %{name: "negative framerate", input: {{-3600, 1}, {{-24, 1}, []}}},
      %{name: "non-rounded ntsc", input: {{1, 1}, {{24_000, 1001}, ["non_drop"]}}},
      %{name: "non-rounded whole", input: {{24_000, 1001}, {{24, 1}, []}}}
    ]

    table_test "fails on <%= name %>", bad_load_table, test_case do
      %{input: input} = test_case
      assert :error = Framestamp.load(input)
    end
  end

  property "dump/1 -> load/1 round trip" do
    check all(framestamp <- StreamDataVtc.framestamp()) do
      assert {:ok, dumped} = Framestamp.dump(framestamp)
      assert {:ok, ^framestamp} = Framestamp.load(dumped)
    end
  end

  describe "#SELECT" do
    table_test "placeholder | <%= app_value %>", serialization_table, test_case do
      %{app_value: app_value, db_value: db_value} = test_case

      query = Query.from(f in fragment("SELECT ? as r", type(^app_value, Framestamp)), select: f.r)
      assert Repo.one!(query) == db_value
    end

    property "succeeds on good framestamp" do
      check all(framestamp <- StreamDataVtc.framestamp()) do
        query = Query.from(f in fragment("SELECT ? as r", type(^framestamp, Framestamp)), select: f.r)
        assert record = Repo.one!(query)
        assert {:ok, ^framestamp} = Framestamp.load(record)
      end
    end
  end

  describe "#table serialization" do
    table_test "can insert <%= app_value %> without constraints", serialization_table, test_case do
      %{app_value: app_value} = test_case

      assert {:ok, inserted} =
               %FramestampSchema01{}
               |> FramestampSchema01.changeset(%{a: app_value})
               |> Repo.insert()

      assert %FramestampSchema01{} = inserted
      assert inserted.a == app_value
      assert inserted.b == nil

      assert %FramestampSchema01{} = record = Repo.get(FramestampSchema01, inserted.id)
      assert record.a == app_value
      assert record.b == nil
    end

    table_test "can insert <%= app_value %> with constraints", serialization_table, test_case do
      %{app_value: app_value} = test_case

      assert {:ok, inserted} =
               %FramestampSchema01{}
               |> FramestampSchema01.changeset(%{b: app_value})
               |> Repo.insert()

      assert %FramestampSchema01{} = inserted
      assert inserted.a == nil
      assert inserted.b == app_value

      assert %FramestampSchema01{} = record = Repo.get(FramestampSchema01, inserted.id)
      assert record.a == nil
      assert record.b == app_value
    end

    property "succeeds on good framestamp" do
      check all(framestamp <- StreamDataVtc.framestamp()) do
        assert {:ok, inserted} =
                 %FramestampSchema01{}
                 |> FramestampSchema01.changeset(%{a: framestamp, b: framestamp})
                 |> Repo.insert()

        assert %FramestampSchema01{} = inserted
        assert inserted.a == framestamp
        assert inserted.b == framestamp

        assert %FramestampSchema01{} = record = Repo.get(FramestampSchema01, inserted.id)
        assert record.a == framestamp
        assert record.b == framestamp
      end
    end

    bad_insert_table = [
      %{
        name: "framerate negative",
        sql_string: "(1, 1, -24, 1, '{}')",
        framestamp: %Framestamp{seconds: Ratio.new(1), rate: %Framerate{playback: Ratio.new(-24), ntsc: nil}},
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "framerate zero ",
        sql_string: "(1, 1, 0, 1, '{}')",
        framestamp: %Framestamp{seconds: Ratio.new(1), rate: %Framerate{playback: Ratio.new(0), ntsc: nil}},
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "framerate zero denominator",
        sql_string: "(1, 1, 24, 0, '{}')",
        framestamp: %Framestamp{
          seconds: Ratio.new(1),
          rate: %Framerate{playback: %Ratio{numerator: 24, denominator: 0}, ntsc: nil}
        },
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "framerate negative denominator",
        sql_string: "(1, 1, 1, -1, '{}')",
        framestamp: %Framestamp{
          seconds: Ratio.new(1),
          rate: %Framerate{playback: %Ratio{numerator: 1, denominator: -1}, ntsc: nil}
        },
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "framerate bad tag with constraints",
        sql_string: "(18018, 5, 24000, 1001, '{bad_tag}')",
        field: :b,
        expected_code: :invalid_text_representation
      },
      %{
        name: "framerate bad tag without constraints",
        sql_string: "(18018, 5, 24000, 1001, '{bad_tag}')",
        field: :a,
        expected_code: :invalid_text_representation
      },
      %{
        name: "framerate multiple ntsc tags",
        sql_string: "(0, 1, 30000, 1001, '{drop, non_drop}')",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_ntsc_tags"
      },
      %{
        name: "framerate bad ntsc rate",
        sql_string: "(1, 1, 24, 1, '{non_drop}')",
        framestamp: %Framestamp{
          seconds: Ratio.new(1),
          rate: %Framerate{playback: %Ratio{numerator: 24, denominator: 1}, ntsc: :non_drop}
        },
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_ntsc_valid"
      },
      %{
        name: "framerate bad drop rate",
        sql_string: "(0, 1, 24000, 1001, '{drop}')",
        framestamp: %Framestamp{
          seconds: Ratio.new(0),
          rate: %Framerate{playback: %Ratio{numerator: 24_000, denominator: 1001}, ntsc: :drop}
        },
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_ntsc_drop_valid"
      },
      %{
        name: "framestamp bad seconds",
        sql_string: "(1, 1, 24000, 1001, '{non_drop}')",
        framestamp: %Framestamp{
          seconds: Ratio.new(1),
          rate: %Framerate{playback: %Ratio{numerator: 24_000, denominator: 1001}, ntsc: :non_drop}
        },
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_seconds_divisible_by_rate"
      }
    ]

    table_test "error <%= name %>", bad_insert_table, test_case do
      %{sql_string: sql_string, expected_code: expected_code, field: field} = test_case

      value_str = "#{sql_string}::framestamp"
      {a, b} = if field == :a, do: {value_str, "NULL"}, else: {"NULL", value_str}

      id = Ecto.UUID.generate()
      query = "INSERT INTO framestamps_01 (id, a, b) VALUES ('#{id}', #{a}, #{b})"

      assert {:error, error} = Repo.query(query)
      assert %Postgrex.Error{postgres: %{code: ^expected_code} = postgres} = error

      if expected_code == :check_violation do
        assert postgres.constraint == test_case.expected_constraint
      end
    end

    table_test "changeset constraint error", bad_insert_table, test_case,
      if: test_case.expected_code == :check_violation and Map.has_key?(test_case, :framestamp) do
      %{framestamp: framestamp, field: field} = test_case

      {a, b} = if field == :a, do: {framestamp, nil}, else: {nil, framestamp}

      assert {:error, %Changeset{errors: [{^field, error}]}} =
               %FramestampSchema01{}
               |> FramestampSchema01.changeset(%{a: a, b: b})
               |> Framestamp.validate_constraints(:b)
               |> Repo.insert()

      assert error == {"is invalid", constraint: :check, constraint_name: test_case.expected_constraint}
    end
  end

  describe "#Postgres framestamp.with_seconds/2" do
    property "matches Framestamp.with_seconds/2" do
      check all(
              seconds <- StreamDataVtc.rational(),
              framerate <- StreamDataVtc.framerate()
            ) do
        expected = Framestamp.with_seconds!(seconds, framerate)

        query =
          Query.from(
            f in fragment(
              "SELECT framestamp.with_seconds(?, ?) as r",
              type(^seconds, PgRational),
              type(^framerate, Framerate)
            ),
            select: f.r
          )

        check_result(Repo.one!(query), expected)
      end
    end
  end

  describe "#Postgres framestamp.with_frames/2" do
    property "matches Framestamp.with_frames/2" do
      check all(
              frames <- StreamData.integer(),
              framerate <- StreamDataVtc.framerate()
            ) do
        expected = Framestamp.with_frames!(frames, framerate)

        query =
          Query.from(
            f in fragment(
              "SELECT framestamp.with_frames(?, ?) as r",
              ^frames,
              type(^framerate, Framerate)
            ),
            select: f.r
          )

        assert record = Repo.one!(query)
        assert {:ok, ^expected} = Framestamp.load(record)
      end
    end
  end

  describe "#Postgres framestamp.seconds/1" do
    property "matches elixir value" do
      check all(framestamp <- StreamDataVtc.framestamp()) do
        %{seconds: expected} = framestamp

        query = Query.from(f in fragment("SELECT framestamp.seconds(?) as r", type(^framestamp, Framestamp)), select: f.r)
        assert record = Repo.one!(query)

        assert {:ok, ^expected} = PgRational.load(record)
      end
    end
  end

  describe "#Postgres framestamp.rate/1" do
    property "matches elixir value" do
      check all(framestamp <- StreamDataVtc.framestamp()) do
        %{rate: expected} = framestamp

        query = Query.from(f in fragment("SELECT framestamp.rate(?) as r", type(^framestamp, Framestamp)), select: f.r)
        assert record = Repo.one!(query)

        assert {:ok, ^expected} = Framerate.load(record)
      end
    end
  end

  describe "#Postgres framestamp.frames/1" do
    property "matches Framestamp.frames/2" do
      check all(framestamp <- StreamDataVtc.framestamp()) do
        query =
          Query.from(
            f in fragment("SELECT framestamp.frames(?) as r", type(^framestamp, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)
        assert is_integer(result)
        assert result == Framestamp.frames(framestamp, round: :trunc)
      end
    end
  end

  describe "Postgres = (equals)" do
    setup context, do: TestCase.setup_framestamps(context)

    property "matches Framestamp" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(f in fragment("SELECT (? = ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == Framestamp.eq?(a, b)
      end
    end

    @tag framestamps: [:a, :b]
    table_test "can be used in WHERE table.field | <%= a %> = <%= b %>", CommonTables.framestamp_compare(), test_case do
      test_case
      |> Map.update(:expected, nil, &(&1 == :eq))
      |> run_table_comparison_test(fn query -> Query.where(query, [r], r.a == r.b) end)
    end
  end

  describe "Postgres === (strict equals)" do
    setup context, do: TestCase.setup_framestamps(context)

    property "matches Framestamp" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        expected = Framestamp.eq?(a, b) and a.rate == b.rate

        query =
          Query.from(f in fragment("SELECT (? === ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == expected
      end
    end

    @tag framestamps: [:a, :b]
    table_test "can be used in WHERE table.field | <%= a %> === <%= b %>", CommonTables.framestamp_compare(), test_case do
      test_case
      |> Map.update(:expected, nil, &(&1 == :eq and test_case.a.rate == test_case.b.rate))
      |> run_table_comparison_test(fn query -> Query.where(query, [r], fragment("? === ?", r.a, r.b)) end)
    end
  end

  describe "Postgres <> (not equals)" do
    setup context, do: TestCase.setup_framestamps(context)

    property "<> matches Framestamp" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(f in fragment("SELECT (? <> ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == not Framestamp.eq?(a, b)
      end
    end

    property "!= matches Framestamp" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(f in fragment("SELECT (? != ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == not Framestamp.eq?(a, b)
      end
    end

    @tag framestamps: [:a, :b]
    table_test "<> can be used in WHERE table.field | <%= a %> <> <%= b %>",
               CommonTables.framestamp_compare(),
               test_case do
      test_case
      |> Map.update(:expected, nil, &(&1 != :eq))
      |> run_table_comparison_test(fn query -> Query.where(query, [r], fragment("? <> ?", r.a, r.b)) end)
    end

    @tag framestamps: [:a, :b]
    table_test "!= can be used in WHERE table.field | <%= a %> != <%= b %>",
               CommonTables.framestamp_compare(),
               test_case do
      test_case
      |> Map.update(:expected, nil, &(&1 != :eq))
      |> run_table_comparison_test(fn query -> Query.where(query, [r], r.a != r.b) end)
    end
  end

  describe "Postgres !=== (strict not equals)" do
    setup context, do: TestCase.setup_framestamps(context)

    property "matches Framestamp" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        expected = not Framestamp.eq?(a, b) or a.rate != b.rate

        query =
          Query.from(f in fragment("SELECT (? !=== ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == expected
      end
    end

    @tag framestamps: [:a, :b]
    table_test "can be used in WHERE table.field | <%= a %> === <%= b %>", CommonTables.framestamp_compare(), test_case do
      test_case
      |> Map.update(:expected, nil, &(&1 != :eq or test_case.a.rate != test_case.b.rate))
      |> run_table_comparison_test(fn query -> Query.where(query, [r], fragment("? !=== ?", r.a, r.b)) end)
    end
  end

  describe "Postgres < (less than)" do
    setup context, do: TestCase.setup_framestamps(context)

    property "matches Framestamp" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(f in fragment("SELECT (? < ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == Framestamp.lt?(a, b)
      end
    end

    @tag framestamps: [:a, :b]
    table_test "can be used in WHERE table.field | <%= a %> < <%= b %>", CommonTables.framestamp_compare(), test_case do
      test_case
      |> Map.update(:expected, nil, &(&1 == :lt))
      |> run_table_comparison_test(fn query -> Query.where(query, [r], r.a < r.b) end)
    end
  end

  describe "Postgres <= (less than or equal to)" do
    setup context, do: TestCase.setup_framestamps(context)

    property "matches Framestamp" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(f in fragment("SELECT (? <= ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == Framestamp.lte?(a, b)
      end
    end

    @tag framestamps: [:a, :b]
    table_test "can be used in WHERE table.field | <%= a %> <= <%= b %>", CommonTables.framestamp_compare(), test_case do
      test_case
      |> Map.update(:expected, nil, &(&1 in [:lt, :eq]))
      |> run_table_comparison_test(fn query -> Query.where(query, [r], r.a <= r.b) end)
    end
  end

  describe "Postgres > (greater than)" do
    setup context, do: TestCase.setup_framestamps(context)

    property "matches Framestamp" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(f in fragment("SELECT (? > ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == Framestamp.gt?(a, b)
      end
    end

    @tag framestamps: [:a, :b]
    table_test "can be used in WHERE table.field | <%= a %> > <%= b %>", CommonTables.framestamp_compare(), test_case do
      test_case
      |> Map.update(:expected, nil, &(&1 == :gt))
      |> run_table_comparison_test(fn query -> Query.where(query, [r], r.a > r.b) end)
    end
  end

  describe "Postgres >= (greater than)" do
    setup context, do: TestCase.setup_framestamps(context)

    property "matches Framestamp" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(f in fragment("SELECT (? >= ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)

        assert is_boolean(result)
        assert result == Framestamp.gte?(a, b)
      end
    end

    @tag framestamps: [:a, :b]
    table_test "can be used in WHERE table.field | <%= a %> >= <%= b %>", CommonTables.framestamp_compare(), test_case do
      test_case
      |> Map.update(:expected, nil, &(&1 in [:gt, :eq]))
      |> run_table_comparison_test(fn query -> Query.where(query, [r], r.a >= r.b) end)
    end
  end

  describe "Postgres framestamp.__private__cmp/2" do
    setup context, do: TestCase.setup_framestamps(context)

    property "matches Framestamp" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(
            f in fragment("SELECT framestamp.__private__cmp(?, ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        result = Repo.one!(query)

        expected =
          case Framestamp.compare(a, b) do
            :lt -> -1
            :eq -> 0
            :gt -> 1
          end

        assert is_integer(result)
        assert result == expected
      end
    end

    @tag framestamps: [:a, :b]
    table_test "can be used in WHERE table.field | <%= a %> >= <%= b %>", CommonTables.framestamp_compare(), test_case do
      expected =
        case test_case.expected do
          :lt -> -1
          :eq -> 0
          :gt -> 1
        end

      test_case
      |> Map.put(:expected, true)
      |> run_table_comparison_test(fn query ->
        Query.where(query, [r], fragment("framestamp.__private__cmp(?, ?) = ?", r.a, r.b, ^expected))
      end)
    end
  end

  describe "ORDER BY support" do
    test "can ORDER BY framestamp field" do
      record_01_start = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      record_02_start = Framestamp.with_frames!("01:00:00:01", Rates.f23_98())
      record_03_start = Framestamp.with_frames!("00:59:59:23", Rates.f23_98())

      record_01 = %FramestampSchema01{} |> FramestampSchema01.changeset(%{a: record_01_start}) |> Repo.insert!()
      record_02 = %FramestampSchema01{} |> FramestampSchema01.changeset(%{a: record_02_start}) |> Repo.insert!()
      record_03 = %FramestampSchema01{} |> FramestampSchema01.changeset(%{a: record_03_start}) |> Repo.insert!()

      records =
        FramestampSchema01
        |> Query.from(order_by: :a)
        |> Repo.all()

      assert is_list(records)
      assert length(records) == 3

      returned_ids = Enum.map(records, & &1.id)
      expected_ids = [record_03.id, record_01.id, record_02.id]

      assert returned_ids == expected_ids
    end

    property "matches Framestamp" do
      check all(
              record_01_start <- StreamDataVtc.framestamp(),
              record_02_start <- StreamDataVtc.framestamp(),
              record_03_start <- StreamDataVtc.framestamp()
            ) do
        record_01 = %FramestampSchema01{} |> FramestampSchema01.changeset(%{a: record_01_start}) |> Repo.insert!()
        record_02 = %FramestampSchema01{} |> FramestampSchema01.changeset(%{a: record_02_start}) |> Repo.insert!()
        record_03 = %FramestampSchema01{} |> FramestampSchema01.changeset(%{a: record_03_start}) |> Repo.insert!()

        record_ids = [record_01.id, record_02.id, record_03.id]

        records =
          FramestampSchema01
          |> Query.from(order_by: [:a, :id])
          |> Query.where([r], r.id in ^record_ids)
          |> Repo.all()

        assert is_list(records)
        assert length(records) == 3

        returned_ids = Enum.map(records, & &1.id)

        expected_ids =
          [record_01, record_02, record_03]
          |> Enum.sort_by(& &1.id)
          |> Enum.sort_by(& &1.a, Framestamp)
          |> Enum.map(& &1.id)

        assert returned_ids == expected_ids
      end
    end
  end

  describe "Postgres + (add, no rate inheritance)" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b, :expected]

    table_test "<%= a %> + <%= b %> == <%= expected %>", CommonTables.framestamp_add(), test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case

      query =
        Query.from(f in fragment("SELECT (? + ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
          select: f.r
        )

      check_result(Repo.one!(query), expected)
    end

    mixed_rate_error_table = [
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f24()),
        b: Framestamp.with_frames!("01:00:00:00", Rates.f48())
      },
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Framestamp.with_frames!("01:00:00:00", Framerate.new!(Ratio.new(24_000, 1001), ntsc: nil))
      },
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_ndf()),
        b: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_df())
      }
    ]

    table_test "<%= a %> + <%= b %> raises on mixed rate", mixed_rate_error_table, test_case do
      %{a: a, b: b} = test_case

      query =
        Query.from(f in fragment("SELECT (? + ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
          select: f.r
        )

      %{postgres: error} = assert_raise Postgrex.Error, fn -> Repo.one!(query) end
      assert error.code == :data_exception
      assert error.message == "Mixed framerate arithmetic"

      assert error.hint ==
               "try using `@+` or `+@` instead. alternatively, do calculations in seconds" <>
                 " before casting back to framestamp with the appropriate framerate using `with_seconds/2`"
    end

    property "matches Framestamp.add/2" do
      check all(
              rate <- StreamDataVtc.framerate(),
              a <- StreamDataVtc.framestamp(rate: rate),
              b <- StreamDataVtc.framestamp(rate: rate)
            ) do
        query =
          Query.from(f in fragment("SELECT (? + ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        check_result(Repo.one!(query), Framestamp.add(a, b))
      end
    end

    property "table fields" do
      check all(
              rate <- StreamDataVtc.framerate(),
              a <- StreamDataVtc.framestamp(rate: rate),
              b <- StreamDataVtc.framestamp(rate: rate)
            ) do
        result =
          run_schema_arithmetic_test(a, b, fn query ->
            Query.select(query, [r], r.a + r.b)
          end)

        check_result(result, Framestamp.add(a, b))
      end
    end
  end

  describe "Postgres @+ (add, left rate inheritance)" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b, :expected]

    table_test "<%= a %> @+ <%= b %> == <%= expected %>", CommonTables.framestamp_add(), test_case,
      if: (is_binary(test_case.a) and is_binary(test_case.b)) or Keyword.get(test_case.opts, :inherit_rate) == :left do
      %{a: a, b: b, expected: expected} = test_case

      query =
        Query.from(f in fragment("SELECT (? @+ ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
          select: f.r
        )

      check_result(Repo.one!(query), expected)
    end

    property "matches Framestamp.add/2" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        query =
          Query.from(f in fragment("SELECT (? @+ ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
            select: f.r
          )

        check_result(Repo.one!(query), Framestamp.add(a, b, inherit_rate: :left))
      end
    end

    property "table fields" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        result =
          run_schema_arithmetic_test(a, b, fn query ->
            Query.select(query, [r], fragment("(? @+ ?)", r.a, r.b))
          end)

        check_result(result, Framestamp.add(a, b, inherit_rate: :left))
      end
    end
  end

  describe "Postgres +@ (add, right rate inheritance)" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b, :expected]

    table_test "<%= a %> +@ <%= b %> == <%= expected %>", CommonTables.framestamp_add(), test_case,
      if: (is_binary(test_case.a) and is_binary(test_case.b)) or Keyword.get(test_case.opts, :inherit_rate) == :right do
      %{a: a, b: b, expected: expected} = test_case

      Query.from(f in fragment("SELECT (? +@ ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
        select: f.r
      )
      |> Repo.one!()
      |> check_result(expected)
    end

    property "matches Framestamp.add/2" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        expected = Framestamp.add(a, b, inherit_rate: :right)

        Query.from(f in fragment("SELECT (? +@ ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
          select: f.r
        )
        |> Repo.one!()
        |> check_result(expected)
      end
    end

    property "table fields" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        result =
          run_schema_arithmetic_test(a, b, fn query ->
            Query.select(query, [r], fragment("(? +@ ?)", r.a, r.b))
          end)

        check_result(result, Framestamp.add(a, b, inherit_rate: :right))
      end
    end
  end

  describe "Postgres - (subtract, no rate inheritance)" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b, :expected]

    table_test "<%= a %> - <%= b %> == <%= expected %>", CommonTables.framestamp_subtract(), test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case

      Query.from(f in fragment("SELECT (? - ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
        select: f.r
      )
      |> Repo.one!()
      |> check_result(expected)
    end

    mixed_rate_error_table = [
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f24()),
        b: Framestamp.with_frames!("01:00:00:00", Rates.f48())
      },
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Framestamp.with_frames!("01:00:00:00", Framerate.new!(Ratio.new(24_000, 1001), ntsc: nil))
      },
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_ndf()),
        b: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_df())
      }
    ]

    table_test "<%= a %> - <%= b %> raises on mixed rate", mixed_rate_error_table, test_case do
      %{a: a, b: b} = test_case

      query =
        Query.from(f in fragment("SELECT (? - ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
          select: f.r
        )

      %{postgres: error} = assert_raise Postgrex.Error, fn -> Repo.one!(query) end
      assert error.code == :data_exception
      assert error.message == "Mixed framerate arithmetic"

      assert error.hint ==
               "try using `@-` or `-@` instead. alternatively, do calculations in seconds" <>
                 " before casting back to framestamp with the appropriate framerate using `with_seconds/2`"
    end

    property "matches Framestamp.sub/2" do
      check all(
              rate <- StreamDataVtc.framerate(),
              a <- StreamDataVtc.framestamp(rate: rate),
              b <- StreamDataVtc.framestamp(rate: rate)
            ) do
        expected = Framestamp.sub(a, b)

        Query.from(f in fragment("SELECT (? - ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
          select: f.r
        )
        |> Repo.one!()
        |> check_result(expected)
      end
    end

    property "table fields" do
      check all(
              rate <- StreamDataVtc.framerate(),
              a <- StreamDataVtc.framestamp(rate: rate),
              b <- StreamDataVtc.framestamp(rate: rate)
            ) do
        result =
          run_schema_arithmetic_test(a, b, fn query ->
            Query.select(query, [r], r.a - r.b)
          end)

        check_result(result, Framestamp.sub(a, b))
      end
    end
  end

  describe "Postgres @- (subtract, left rate inheritance)" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b, :expected]

    table_test "<%= a %> @- <%= b %> == <%= expected %>", CommonTables.framestamp_subtract(), test_case,
      if: (is_binary(test_case.a) and is_binary(test_case.b)) or Keyword.get(test_case.opts, :inherit_rate) == :left do
      %{a: a, b: b, expected: expected} = test_case

      Query.from(f in fragment("SELECT (? @- ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
        select: f.r
      )
      |> Repo.one!()
      |> check_result(expected)
    end

    property "matches Framestamp.sub/2" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        expected = Framestamp.sub(a, b, inherit_rate: :left)

        Query.from(f in fragment("SELECT (? @- ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
          select: f.r
        )
        |> Repo.one!()
        |> check_result(expected)
      end
    end

    property "table fields" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        result =
          run_schema_arithmetic_test(a, b, fn query ->
            Query.select(query, [r], fragment("(? @- ?)", r.a, r.b))
          end)

        check_result(result, Framestamp.sub(a, b, inherit_rate: :left))
      end
    end
  end

  describe "Postgres -@ (subtract, right rate inheritance)" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b, :expected]

    table_test "<%= a %> -@ <%= b %> == <%= expected %>", CommonTables.framestamp_subtract(), test_case,
      if: (is_binary(test_case.a) and is_binary(test_case.b)) or Keyword.get(test_case.opts, :inherit_rate) == :right do
      %{a: a, b: b, expected: expected} = test_case

      Query.from(f in fragment("SELECT (? -@ ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
        select: f.r
      )
      |> Repo.one!()
      |> check_result(expected)
    end

    property "matches Framestamp.sub/2" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        expected = Framestamp.sub(a, b, inherit_rate: :right)

        Query.from(f in fragment("SELECT (? -@ ?) as r", type(^a, Framestamp), type(^b, Framestamp)),
          select: f.r
        )
        |> Repo.one!()
        |> check_result(expected)
      end
    end

    property "table fields" do
      check all(
              a <- StreamDataVtc.framestamp(),
              b <- StreamDataVtc.framestamp()
            ) do
        result =
          run_schema_arithmetic_test(a, b, fn query ->
            Query.select(query, [r], fragment("(? -@ ?)", r.a, r.b))
          end)

        check_result(result, Framestamp.sub(a, b, inherit_rate: :right))
      end
    end
  end

  describe "Postgres * (multiply) by rational" do
    property "matches Framestamp.mult/2" do
      check all(
              a <- StreamDataVtc.framestamp(),
              multiplier <- StreamDataVtc.rational()
            ) do
        query =
          Query.from(f in fragment("SELECT (? * ?) as r", type(^a, Framestamp), type(^multiplier, PgRational)),
            select: f.r
          )

        check_result(Repo.one!(query), Framestamp.mult(a, multiplier))
      end
    end

    property "table fields" do
      check all(
              a <- StreamDataVtc.framestamp(),
              multiplier <- StreamDataVtc.rational()
            ) do
        b = Framestamp.with_frames!(0, a.rate)

        result =
          run_schema_arithmetic_test(a, b, fn query ->
            Query.select(query, [r], r.a * type(^multiplier, PgRational))
          end)

        check_result(result, Framestamp.mult(a, multiplier))
      end
    end
  end

  describe "Postgres / (divide) by rational" do
    property "matches Framestamp.div/2 with round: closest" do
      check all(
              dividend <- StreamDataVtc.framestamp(),
              divisor <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, 0)))
            ) do
        query =
          Query.from(f in fragment("SELECT (? / ?) as r", type(^dividend, Framestamp), type(^divisor, PgRational)),
            select: f.r
          )

        check_result(Repo.one!(query), Framestamp.div(dividend, divisor, round: :closest))
      end
    end

    property "table fields" do
      check all(
              dividend <- StreamDataVtc.framestamp(),
              divisor <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, 0)))
            ) do
        b = Framestamp.with_frames!(0, dividend.rate)

        result =
          run_schema_arithmetic_test(dividend, b, fn query ->
            Query.select(query, [r], r.a / type(^divisor, PgRational))
          end)

        check_result(result, Framestamp.div(dividend, divisor, round: :closest))
      end
    end
  end

  describe "Postgres DIV/1 (floor divide) by rational" do
    property "matches Framestamp.div/2 with round: trunc" do
      check all(
              dividend <- StreamDataVtc.framestamp(),
              divisor <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, 0)))
            ) do
        query =
          Query.from(f in fragment("SELECT DIV(?, ?) as r", type(^dividend, Framestamp), type(^divisor, PgRational)),
            select: f.r
          )

        check_result(Repo.one!(query), Framestamp.div(dividend, divisor, round: :trunc))
      end
    end

    property "table fields" do
      check all(
              dividend <- StreamDataVtc.framestamp(),
              divisor <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, 0)))
            ) do
        b = Framestamp.with_frames!(0, dividend.rate)

        result =
          run_schema_arithmetic_test(dividend, b, fn query ->
            Query.select(query, [r], fragment("DIV(?, ?)", r.a, type(^divisor, PgRational)))
          end)

        check_result(result, Framestamp.div(dividend, divisor, round: :trunc))
      end
    end
  end

  describe "Postgres % (modulo) by rational" do
    property "matches Framestamp.rem/3" do
      check all(
              dividend <- StreamDataVtc.framestamp(),
              divisor <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, 0)))
            ) do
        query =
          Query.from(f in fragment("SELECT (? % ?) as r", type(^dividend, Framestamp), type(^divisor, PgRational)),
            select: f.r
          )

        check_result(Repo.one!(query), Framestamp.rem(dividend, divisor))
      end
    end

    property "table fields" do
      check all(
              dividend <- StreamDataVtc.framestamp(),
              divisor <- StreamData.filter(StreamDataVtc.rational(), &(not Ratio.eq?(&1, 0)))
            ) do
        b = Framestamp.with_frames!(0, dividend.rate)

        result =
          run_schema_arithmetic_test(dividend, b, fn query ->
            Query.select(query, [r], fragment("(? % ?)", r.a, type(^divisor, PgRational)))
          end)

        check_result(result, Framestamp.rem(dividend, divisor))
      end
    end
  end

  @spec run_table_comparison_test(
          %{a: Framestamp.t(), b: Framestamp.t(), expected: boolean()},
          (Queryable.t() -> Query.t())
        ) :: term()
  defp run_table_comparison_test(test_case, where_filter) do
    %{a: a, b: b, expected: expected} = test_case

    assert {:ok, %{id: record_id}} =
             %FramestampSchema01{}
             |> FramestampSchema01.changeset(%{a: a, b: b})
             |> Repo.insert()

    result =
      FramestampSchema01
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
  @spec run_schema_arithmetic_test(Framestamp.t(), Framestamp.t(), (Queryable.t() -> Query.t())) :: Framestamp.t()
  defp run_schema_arithmetic_test(a, b, select) do
    assert {:ok, %{id: record_id}} =
             %FramestampSchema01{}
             |> FramestampSchema01.changeset(%{a: a, b: b})
             |> Repo.insert()

    FramestampSchema01
    |> select.()
    |> Query.where([r], r.id == ^record_id)
    |> Repo.one!()
  end

  @spec check_result(PgFramestamp.db_record(), Framestamp.t()) :: :ok
  defp check_result(result, expected) do
    {seconds_n, seconds_d, rate_n, rate_d, _} = result

    assert {:ok, ^expected} = Framestamp.load(result)

    ## Make sure the result came in simplified and it wasn't simplified during loading
    assert seconds_n == expected.seconds.numerator
    assert seconds_d == expected.seconds.denominator

    assert rate_n == expected.rate.playback.numerator
    assert rate_d == expected.rate.playback.denominator

    :ok
  end
end
