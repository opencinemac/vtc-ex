defmodule Vtc.Ecto.Postgres.PgTimecodeTest do
  use Vtc.Test.Support.EctoCase, async: true
  use ExUnitProperties

  alias Ecto.Changeset
  alias Ecto.Query
  alias Vtc.Rates
  alias Vtc.Test.Support.TimecodeSchema01
  alias Vtc.TestUtls.StreamDataVtc
  alias Vtc.Timecode

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
        expected: Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      },
      %{
        input: %{
          smpte_timecode: "-01:00:00:00",
          rate: %{
            playback: "24000/1001",
            ntsc: :non_drop
          }
        },
        expected: Timecode.with_frames!("-01:00:00:00", Rates.f23_98())
      },
      %{
        input: %{
          smpte_timecode: "01:00:00:00",
          rate: %{
            playback: [30_000, 1001],
            ntsc: :drop
          }
        },
        expected: Timecode.with_frames!("01:00:00:00", Rates.f29_97_df())
      },
      %{
        input: %{
          smpte_timecode: "-01:00:00:00",
          rate: %{
            playback: [30_000, 1001],
            ntsc: :drop
          }
        },
        expected: Timecode.with_frames!("-01:00:00:00", Rates.f29_97_df())
      },
      %{
        input: %{
          smpte_timecode: "01:00:00:00",
          rate: %{
            playback: [30_000, 1001],
            ntsc: "non_drop"
          }
        },
        expected: Timecode.with_frames!("01:00:00:00", Rates.f29_97_ndf())
      }
    ]

    table_test "<%= expected %>", cast_table, test_case do
      %{input: input, expected: expected} = test_case
      assert {:ok, ^expected} = Timecode.cast(input)
    end

    table_test "<%= expected %> | string keys", cast_table, test_case do
      %{input: input, expected: expected} = test_case
      input = convert_input_to_string_keys(input)

      assert {:ok, ^expected} = Timecode.cast(input)
    end

    table_test "<%= expected %> | through changeset", cast_table, test_case do
      %{input: input, expected: expected} = test_case

      assert {:ok, record} =
               %TimecodeSchema01{}
               |> TimecodeSchema01.changeset(%{a: input, b: input})
               |> Changeset.apply_action(:test)

      assert record.a == expected
      assert record.b == expected
    end

    table_test "<%= expected %> | through changeset | string keys", cast_table, test_case do
      %{input: input, expected: expected} = test_case
      input = convert_input_to_string_keys(input)

      assert {:ok, record} =
               %TimecodeSchema01{}
               |> TimecodeSchema01.changeset(%{a: input, b: input})
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
      assert :error = Timecode.cast(input)
    end

    property "succeeds on good timecode json" do
      check all(timecode <- StreamDataVtc.timecode(rate_opts: [type: [:whole, :drop, :non_drop]])) do
        input = %{
          smpte_timecode: Timecode.timecode(timecode),
          rate: %{
            playback: [timecode.rate.playback.numerator, timecode.rate.playback.denominator],
            ntsc: timecode.rate.ntsc
          }
        }

        timecode_str = Timecode.timecode(timecode)
        assert {:ok, parsed} = Timecode.with_frames(timecode_str, timecode.rate)
        assert parsed == timecode

        assert {:ok, result} = Timecode.cast(input)
        assert result == timecode
      end
    end
  end

  serialization_table = [
    %{
      app_value: Timecode.with_frames!("01:00:00:00", Rates.f23_98()),
      db_value: {{18_018, 5}, {{24_000, 1001}, ["non_drop"]}}
    },
    %{
      app_value: Timecode.with_frames!("-01:00:00:00", Rates.f23_98()),
      db_value: {{-18_018, 5}, {{24_000, 1001}, ["non_drop"]}}
    },
    %{
      app_value: Timecode.with_frames!("01:00:00:00", Rates.f29_97_df()),
      db_value: {{8_999_991, 2500}, {{30_000, 1001}, ["drop"]}}
    },
    %{
      app_value: Timecode.with_frames!("-01:00:00:00", Rates.f29_97_df()),
      db_value: {{-8_999_991, 2500}, {{30_000, 1001}, ["drop"]}}
    },
    %{
      app_value: Timecode.with_frames!("01:00:00:00", Rates.f24()),
      db_value: {{3600, 1}, {{24, 1}, []}}
    },
    %{
      app_value: Timecode.with_frames!("-01:00:00:00", Rates.f24()),
      db_value: {{-3600, 1}, {{24, 1}, []}}
    }
  ]

  describe "#dump/1" do
    table_test "succeeds on <%= app_value %>", serialization_table, test_case do
      %{db_value: db_value, app_value: app_value} = test_case
      assert {:ok, ^db_value} = Timecode.dump(app_value)
    end

    bad_dump_table = [
      %{input: "01:00:00:00"},
      %{input: Ratio.new(3600, 1)},
      %{input: {"01:00:00:00", Rates.f23_98()}},
      %{input: {{-3600, 1}, {{24, 1}, []}}}
    ]

    table_test "fails on <%= input %>", bad_dump_table, test_case do
      %{input: input} = test_case
      assert :error = Timecode.dump(input)
    end
  end

  describe "#load/1" do
    table_test "succeeds on <%= app_value %>", serialization_table, test_case do
      %{db_value: db_value, app_value: app_value} = test_case
      assert {:ok, ^app_value} = Timecode.load(db_value)
    end

    bad_load_table = [
      %{name: "bad drop framerate", input: {{8_999_991, 2500}, {{30_000, 1002}, ["drop"]}}},
      %{name: "negative framerate", input: {{-3600, 1}, {{-24, 1}, []}}},
      %{name: "non-rounded ntsc", input: {{1, 1}, {{24_000, 1001}, ["non_drop"]}}},
      %{name: "non-rounded whole", input: {{24_000, 1001}, {{24, 1}, []}}}
    ]

    table_test "fails on <%= name %>", bad_load_table, test_case do
      %{input: input} = test_case
      assert :error = Timecode.load(input)
    end
  end

  property "dump/1 -> load/1 round trip" do
    check all(timecode <- StreamDataVtc.timecode()) do
      assert {:ok, dumped} = Timecode.dump(timecode)
      assert {:ok, ^timecode} = Timecode.load(dumped)
    end
  end

  describe "#SELECT" do
    table_test "placeholder | <%= app_value %>", serialization_table, test_case do
      %{app_value: app_value, db_value: db_value} = test_case

      query = Query.from(f in fragment("SELECT ? as r", type(^app_value, Timecode)), select: f.r)
      assert Repo.one!(query) == db_value
    end

    table_test "seconds field | <%= app_value %>", serialization_table, test_case do
      %{db_value: {expected, _}, app_value: app_value} = test_case

      query = Query.from(f in fragment("SELECT (?).seconds as r", type(^app_value, Timecode)), select: f.r)
      assert Repo.one!(query) == expected
    end

    table_test "rate field | <%= app_value %>", serialization_table, test_case do
      %{db_value: {_, expected}, app_value: app_value} = test_case

      query = Query.from(f in fragment("SELECT (?).rate as r", type(^app_value, Timecode)), select: f.r)
      assert Repo.one!(query) == expected
    end

    property "succeeds on good timecode" do
      check all(timecode <- StreamDataVtc.timecode()) do
        query = Query.from(f in fragment("SELECT ? as r", type(^timecode, Timecode)), select: f.r)
        assert record = Repo.one!(query)
        assert {:ok, ^timecode} = Timecode.load(record)
      end
    end
  end

  describe "#table serialization" do
    table_test "can insert into field without constraints", serialization_table, test_case do
      %{app_value: app_value} = test_case

      assert {:ok, inserted} =
               %TimecodeSchema01{}
               |> TimecodeSchema01.changeset(%{a: app_value})
               |> Repo.insert()

      assert %TimecodeSchema01{} = inserted
      assert inserted.a == app_value
      assert inserted.b == nil

      assert %TimecodeSchema01{} = record = Repo.get(TimecodeSchema01, inserted.id)
      assert record.a == app_value
      assert record.b == nil
    end

    property "succeeds on good timecode" do
      check all(timecode <- StreamDataVtc.timecode()) do
        assert {:ok, inserted} =
                 %TimecodeSchema01{}
                 |> TimecodeSchema01.changeset(%{a: timecode, b: timecode})
                 |> Repo.insert()

        assert %TimecodeSchema01{} = inserted
        assert inserted.a == timecode
        assert inserted.b == timecode

        assert %TimecodeSchema01{} = record = Repo.get(TimecodeSchema01, inserted.id)
        assert record.a == timecode
        assert record.b == timecode
      end
    end
  end
end
