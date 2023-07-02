defmodule Vtc.Ecto.Postgres.PgFramestampTest do
  use Vtc.Test.Support.EctoCase, async: true
  use ExUnitProperties

  alias Ecto.Changeset
  alias Ecto.Query
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Rates
  alias Vtc.Test.Support.FramestampSchema01
  alias Vtc.TestUtls.StreamDataVtc

  require Query

  describe "#cast/1" do
    cast_table = [
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
          smpte_timecode: Ratio.new(24, 1),
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
      db_value: {{18_018, 5}, {{24_000, 1001}, ["non_drop"]}}
    },
    %{
      app_value: Framestamp.with_frames!("-01:00:00:00", Rates.f23_98()),
      db_value: {{-18_018, 5}, {{24_000, 1001}, ["non_drop"]}}
    },
    %{
      app_value: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_df()),
      db_value: {{8_999_991, 2500}, {{30_000, 1001}, ["drop"]}}
    },
    %{
      app_value: Framestamp.with_frames!("-01:00:00:00", Rates.f29_97_df()),
      db_value: {{-8_999_991, 2500}, {{30_000, 1001}, ["drop"]}}
    },
    %{
      app_value: Framestamp.with_frames!("01:00:00:00", Rates.f24()),
      db_value: {{3600, 1}, {{24, 1}, []}}
    },
    %{
      app_value: Framestamp.with_frames!("-01:00:00:00", Rates.f24()),
      db_value: {{-3600, 1}, {{24, 1}, []}}
    }
  ]

  describe "#dump/1" do
    table_test "succeeds on <%= app_value %>", serialization_table, test_case do
      %{db_value: db_value, app_value: app_value} = test_case
      assert {:ok, ^db_value} = Framestamp.dump(app_value)
    end

    bad_dump_table = [
      %{input: "01:00:00:00"},
      %{input: Ratio.new(3600, 1)},
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

    table_test "seconds field | <%= app_value %>", serialization_table, test_case do
      %{db_value: {expected, _}, app_value: app_value} = test_case

      query = Query.from(f in fragment("SELECT (?).seconds as r", type(^app_value, Framestamp)), select: f.r)
      assert Repo.one!(query) == expected
    end

    table_test "rate field | <%= app_value %>", serialization_table, test_case do
      %{db_value: {_, expected}, app_value: app_value} = test_case

      query = Query.from(f in fragment("SELECT (?).rate as r", type(^app_value, Framestamp)), select: f.r)
      assert Repo.one!(query) == expected
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
        value: "((1, 1), ((-24, 1), '{}'))",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "framerate zero ",
        value: "((1, 1), ((0, 1), '{}'))",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "framerate zero denominator",
        value: "((1, 1), ((24, 0), '{}'))",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "framerate negative denominator",
        value: "((1, 1), ((1, -1), '{}'))",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_positive"
      },
      %{
        name: "framerate bad tag with constraints",
        value: "((18018, 5), ((24000, 1001), '{bad_tag}'))",
        field: :b,
        expected_code: :invalid_text_representation
      },
      %{
        name: "framerate bad tag without constraints",
        value: "((18018, 5), ((24000, 1001), '{bad_tag}'))",
        field: :a,
        expected_code: :invalid_text_representation
      },
      %{
        name: "framerate multiple ntsc tags",
        value: "((0, 1), ((30000, 1001), '{drop, non_drop}'))",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_ntsc_tags"
      },
      %{
        name: "framerate bad ntsc rate",
        value: "((1, 1), ((24, 1), '{non_drop}'))",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_ntsc_valid"
      },
      %{
        name: "framerate bad drop rate",
        value: "((0, 1), ((24000, 1001), '{drop}'))",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_rate_ntsc_drop_valid"
      },
      %{
        name: "framestamp bad seconds",
        value: "((1, 1), ((24000, 1001), '{non_drop}'))",
        field: :b,
        expected_code: :check_violation,
        expected_constraint: "b_seconds_divisible_by_rate"
      }
    ]

    table_test "error <%= name %>", bad_insert_table, test_case do
      %{value: value, expected_code: expected_code, field: field} = test_case

      value_str = "#{value}::framestamp"
      {a, b} = if field == :a, do: {value_str, "NULL"}, else: {"NULL", value_str}

      id = Ecto.UUID.generate()
      query = "INSERT INTO framestamps_01 (id, a, b) VALUES ('#{id}', #{a}, #{b})"

      assert {:error, error} = Repo.query(query)
      assert %Postgrex.Error{postgres: %{code: ^expected_code} = postgres} = error

      if expected_code == :check_violation do
        assert postgres.constraint == test_case.expected_constraint
      end
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

        assert record = Repo.one!(query)
        assert {:ok, ^expected} = Framestamp.load(record)
      end
    end
  end
end
