defmodule Vtc.Ecto.Postgres.PgTimecodeBench do
  @moduledoc false
  use Vtc.Test.Support.BenchCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Vtc.Framerate
  alias Vtc.Rates
  alias Vtc.Test.Support.SplitTimecodesSchema
  alias Vtc.Test.Support.TimecodeSchema01
  alias Vtc.Timecode

  @moduletag :skip
  @moduletag :bench

  @tag timeout: 150_000
  test "bench PgTimecode insert" do
    Benchee.run(
      %{
        "insert_pg_timecode" => &bench_insert_pg_timecodes/0,
        "insert_split_timecode_data" => &bench_insert_split_timecodes/0
      },
      warmup: 10,
      time: 15,
      memory_time: 2
    )
  end

  defp bench_insert_pg_timecodes do
    with_repo(&setup_pg_timecode_records/0)
  end

  defp bench_insert_split_timecodes do
    with_repo(&setup_split_records/0)
  end

  @tag timeout: 150_000
  test "bench PgTimecode fetch" do
    Benchee.run(
      %{
        "fetch_pg_timecode" => {
          fn _ -> bench_fetch_pg_timecodes() end,
          before_scenario: fn _ -> setup_pg_timecode_records() end
        },
        "fetch_split_timecode_data" => {
          fn _ -> bench_fetch_split_timecodes() end,
          before_scenario: fn _ -> setup_split_records() end
        }
      },
      warmup: 10,
      time: 15,
      memory_time: 2
    )
  end

  defp bench_fetch_pg_timecodes do
    records = Repo.all(TimecodeSchema01)
    assert length(records) == 10_000
  end

  defp bench_fetch_split_timecodes do
    records =
      SplitTimecodesSchema
      |> Repo.all()
      |> Enum.map(fn record ->
        a_ntsc =
          cond do
            "non_drop" in record.a_tags -> :non_drop
            "drop" in record.a_tags -> :drop
            true -> nil
          end

        a_framerate = Framerate.new!(record.a_rate, ntsc: a_ntsc)
        a_timcode = Timecode.with_seconds!(record.a_seconds, a_framerate, round: :off)

        b_ntsc =
          cond do
            "non_drop" in record.b_tags -> :non_drop
            "drop" in record.b_tags -> :drop
            true -> nil
          end

        b_framerate = Framerate.new!(record.b_rate, ntsc: b_ntsc)
        b_timcode = Timecode.with_seconds!(record.b_seconds, b_framerate, round: :off)

        {a_timcode, b_timcode}
      end)

    assert length(records) == 10_000
  end

  @spec with_repo((() -> result)) :: result when result: any()
  defp with_repo(test_runner) do
    Sandbox.checkout(Repo)

    try do
      test_runner.()
    rescue
      e -> reraise e, __STACKTRACE__
    after
      Sandbox.checkin(Repo)
    end
  end

  defp setup_pg_timecode_records do
    for frame_number <- 1..10_000 do
      insert_pg_timecode_record(frame_number)
    end
  end

  defp setup_split_records do
    for frame_number <- 1..10_000 do
      insert_split_record(frame_number)
    end
  end

  @spec insert_pg_timecode_record(pos_integer()) :: term()
  defp insert_pg_timecode_record(frame_number) do
    timecode = Timecode.with_frames!(frame_number, Rates.f23_98())

    {:ok, _} =
      %TimecodeSchema01{}
      |> TimecodeSchema01.changeset(%{a: timecode, b: timecode})
      |> Repo.insert()
  end

  @spec insert_split_record(pos_integer()) :: term()
  defp insert_split_record(frame_number) do
    timecode = Timecode.with_frames!(frame_number, Rates.f23_98())

    a_tags =
      case timecode.rate do
        %{ntsc: :non_drop} -> ["non_drop"]
        %{ntsc: :drop} -> ["drop"]
        _ -> []
      end

    b_tags =
      case timecode.rate do
        %{ntsc: :non_drop} -> ["non_drop"]
        %{ntsc: :drop} -> ["drop"]
        _ -> []
      end

    attrs = %{
      a_seconds: timecode.seconds,
      a_rate: timecode.rate.playback,
      a_tags: a_tags,
      b_seconds: timecode.seconds,
      b_rate: timecode.rate.playback,
      b_tags: b_tags
    }

    {:ok, _} =
      %SplitTimecodesSchema{}
      |> SplitTimecodesSchema.changeset(attrs)
      |> Repo.insert()
  end
end
