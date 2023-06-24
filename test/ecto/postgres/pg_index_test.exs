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

  alias Ecto.Query
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Test.Support.RationalsSchema02

  require Ecto.Query

  @moduletag :index_test

  describe "PgRational" do
    test "BTREE indexing" do
      assert {:ok, %{id: _}} =
               %RationalsSchema02{}
               |> RationalsSchema02.changeset(%{a: Ratio.new(1, 2), b: Ratio.new(1, 4)})
               |> Repo.insert()

      for denominator <- 1..20_000 do
        assert {:ok, _} =
                 %RationalsSchema02{}
                 |> RationalsSchema02.changeset(%{a: Ratio.new(1, 2), b: Ratio.new(1, denominator)})
                 |> Repo.insert()
      end

      value = Ratio.new(1, 10_000)
      expected_plan_snippet = "Index Scan using rationals_02_b_index on rationals_02 r0"

      lt_plan =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.b < type(^value, PgRational))
        |> then(&Repo.explain(:all, &1))
        |> dbg()

      assert lt_plan =~ expected_plan_snippet

      lte_plan =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.b <= type(^value, PgRational))
        |> then(&Repo.explain(:all, &1))
        |> dbg()

      assert lte_plan =~ expected_plan_snippet

      eq_plan =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.b == type(^value, PgRational))
        |> then(&Repo.explain(:all, &1))
        |> dbg()

      assert eq_plan =~ expected_plan_snippet

      gt_plan =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.b > type(^value, PgRational))
        |> then(&Repo.explain(:all, &1))
        |> dbg()

      assert gt_plan =~ expected_plan_snippet

      gte_plan =
        RationalsSchema02
        |> Query.select([r], r.id)
        |> Query.where([r], r.b >= type(^value, PgRational))
        |> then(&Repo.explain(:all, &1))
        |> dbg()

      assert gte_plan =~ expected_plan_snippet
    end
  end
end
