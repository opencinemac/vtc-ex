defmodule Vtc.Ecto.Postgres.PgRationalIndexTest do
  @moduledoc """
  Expensive tests that insert tens of thousands of records in order to coerce the
  query planner into using an index in order to assert that it CAN, and that operator
  families are working as intended.

  To exclude these tests when running locally, use:

  ```mix
  mix test --exclude index_test
  ```
  """

  use Vtc.Test.Support.EctoCase, async: false

  alias Ecto.Changeset
  alias Ecto.Query
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Framestamp
  alias Vtc.Rates
  alias Vtc.Test.Support.FramestampSchema01
  alias Vtc.Test.Support.FramestampSchema02
  alias Vtc.Test.Support.RationalsSchema02

  require Ecto.Query

  @moduletag :index_test

  describe "PgRational" do
    test "BTREE indexing" do
      inserted =
        1..20_000
        |> Enum.map(fn denominator ->
          RationalsSchema02.changeset(%RationalsSchema02{}, %{
            id: Ecto.UUID.generate(),
            a: Ratio.new(1, 2),
            b: Ratio.new(1, denominator)
          })
        end)
        |> Enum.map(&Changeset.apply_action!(&1, :insert))
        |> Enum.map(&Map.take(&1, [:id, :a, :b]))
        |> then(&Repo.insert_all(RationalsSchema02, &1))

      assert inserted == {20_000, nil}

      value = Ratio.new(1, 10_000)
      expected_plan_snippet = "Index Scan using rationals_02_b_index on rationals_02 r0"

      lt_plan =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.b < type(^value, PgRational))
        |> then(&Repo.explain(:all, &1))

      assert lt_plan =~ expected_plan_snippet

      lte_plan =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.b <= type(^value, PgRational))
        |> then(&Repo.explain(:all, &1))

      assert lte_plan =~ expected_plan_snippet

      eq_plan =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.b == type(^value, PgRational))
        |> then(&Repo.explain(:all, &1))

      assert eq_plan =~ expected_plan_snippet

      gt_plan =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.b > type(^value, PgRational))
        |> then(&Repo.explain(:all, &1))

      assert gt_plan =~ expected_plan_snippet

      gte_plan =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.b >= type(^value, PgRational))
        |> then(&Repo.explain(:all, &1))

      assert gte_plan =~ expected_plan_snippet
    end
  end

  describe "PgFramestamp" do
    test "BTREE indexing" do
      inserted =
        1..20_000
        |> Enum.map(fn frames ->
          FramestampSchema01.changeset(%FramestampSchema01{}, %{
            id: Ecto.UUID.generate(),
            a: Framestamp.with_frames!(12, Rates.f24()),
            b: Framestamp.with_frames!(frames, Rates.f24())
          })
        end)
        |> Enum.map(&Changeset.apply_action!(&1, :insert))
        |> Enum.map(&Map.take(&1, [:id, :a, :b]))
        |> then(&Repo.insert_all(FramestampSchema01, &1))

      assert inserted == {20_000, nil}

      value = Framestamp.with_frames!(1, Rates.f24())
      expected_plan_snippet = "Index Scan using framestamps_01_b_index on framestamps_01 f0"

      lt_plan =
        FramestampSchema01
        |> Query.select([r], r.id)
        |> Query.where([r], r.b < type(^value, Framestamp))
        |> then(&Repo.explain(:all, &1))

      assert lt_plan =~ expected_plan_snippet

      lte_plan =
        FramestampSchema01
        |> Query.select([r], r.id)
        |> Query.where([r], r.b <= type(^value, Framestamp))
        |> then(&Repo.explain(:all, &1))

      assert lte_plan =~ expected_plan_snippet

      eq_plan =
        FramestampSchema01
        |> Query.select([r], r.id)
        |> Query.where([r], r.b == type(^value, Framestamp))
        |> then(&Repo.explain(:all, &1))

      assert eq_plan =~ expected_plan_snippet

      gt_plan =
        FramestampSchema01
        |> Query.select([r], r.id)
        |> Query.where([r], r.b > type(^value, Framestamp))
        |> then(&Repo.explain(:all, &1))

      assert gt_plan =~ expected_plan_snippet

      gte_plan =
        FramestampSchema01
        |> Query.select([r], r.id)
        |> Query.where([r], r.b >= type(^value, Framestamp))
        |> then(&Repo.explain(:all, &1))

      assert gte_plan =~ expected_plan_snippet
    end
  end

  describe "PgFramestampRange" do
    test "framestamp_fastrange | GIST indexing" do
      for _ <- 1..20 do
        inserted =
          1..1_000
          |> Enum.map(fn frames ->
            FramestampSchema02.changeset(%FramestampSchema02{}, %{
              id: Ecto.UUID.generate(),
              a: Framestamp.with_frames!(frames - div(frames, 2), Rates.f24()),
              b: Framestamp.with_frames!(frames, Rates.f24())
            })
          end)
          |> Enum.map(&Changeset.apply_action!(&1, :insert))
          |> Enum.map(&Map.take(&1, [:id, :a, :b]))
          |> then(&Repo.insert_all(FramestampSchema02, &1))

        assert inserted == {1_000, nil}
      end

      expected_plan_snippet = "Index Scan using framestamps_a_b_fastrange on framestamps_02"

      overlaps_plan =
        FramestampSchema02
        |> Query.from(as: :events_01)
        |> Query.join(
          :inner,
          [events_01: events_01],
          events_02 in FramestampSchema02,
          as: :events_02,
          on:
            fragment(
              """
              framestamp_fastrange(?, ?)
              && framestamp_fastrange(?, ?)
              """,
              events_01.a,
              events_01.b,
              events_02.a,
              events_02.b
            )
        )
        |> Query.select([events_01: events_01, events_02: events_02], {events_01.id, events_02.id})
        |> then(&Repo.explain(:all, &1))
        |> dbg()

      assert overlaps_plan =~ expected_plan_snippet
    end

    test "framestamp_range | GIST indexing" do
      for _ <- 1..20 do
        inserted =
          1..1_000
          |> Enum.map(fn frames ->
            FramestampSchema02.changeset(%FramestampSchema02{}, %{
              id: Ecto.UUID.generate(),
              a: Framestamp.with_frames!(frames - div(frames, 2), Rates.f24()),
              b: Framestamp.with_frames!(frames, Rates.f24())
            })
          end)
          |> Enum.map(&Changeset.apply_action!(&1, :insert))
          |> Enum.map(&Map.take(&1, [:id, :a, :b]))
          |> then(&Repo.insert_all(FramestampSchema02, &1))

        assert inserted == {1_000, nil}
      end

      expected_plan_snippet = "Index Scan using framestamps_a_b_range on framestamps_02"

      overlaps_plan =
        FramestampSchema02
        |> Query.from(as: :events_01)
        |> Query.join(
          :inner,
          [events_01: events_01],
          events_02 in FramestampSchema02,
          as: :events_02,
          on:
            fragment(
              """
              framestamp_range(?, ?)
              && framestamp_range(?, ?)
              """,
              events_01.a,
              events_01.b,
              events_02.a,
              events_02.b
            )
        )
        |> Query.select([events_01: events_01, events_02: events_02], {events_01.id, events_02.id})
        |> then(&Repo.explain(:all, &1))
        |> dbg()

      assert overlaps_plan =~ expected_plan_snippet
    end
  end
end
