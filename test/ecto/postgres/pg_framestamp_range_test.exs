defmodule Vtc.Ecto.Postgres.PgFramestampRangeTest do
  use Vtc.Test.Support.EctoCase, async: true
  use ExUnitProperties

  alias Ecto.Query
  alias Vtc.Framestamp
  alias Vtc.Rates

  require Ecto.Query

  describe "#SELECT" do
    test "can construct exclusive range using type/2 fragment" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
      stamp_range = Framestamp.Range.new!(in_stamp, out_stamp)

      query = Query.from(f in fragment("SELECT ? as r", type(^stamp_range, Framestamp.Range)), select: f.r)

      assert %Postgrex.Range{} = result = Repo.one!(query)
      assert {:ok, ^stamp_range} = Framestamp.Range.load(result)
    end

    test "can construct inclusive range using type/2 fragment" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
      stamp_range = Framestamp.Range.new!(in_stamp, out_stamp, out_type: :inclusive)

      query = Query.from(f in fragment("SELECT ? as r", type(^stamp_range, Framestamp.Range)), select: f.r)

      assert %Postgrex.Range{} = result = Repo.one!(query)
      assert {:ok, ^stamp_range} = Framestamp.Range.load(result)
    end

    test "can construct exclusive range using native cast" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
      stamp_range = Framestamp.Range.new!(in_stamp, out_stamp)

      query =
        Query.from(
          f in fragment(
            "SELECT framestamp_range(?, ?, '[)') as r",
            type(^in_stamp, Framestamp),
            type(^out_stamp, Framestamp)
          ),
          select: f.r
        )

      assert %Postgrex.Range{} = result = Repo.one!(query)
      assert {:ok, ^stamp_range} = Framestamp.Range.load(result)
    end

    test "can construct inclusive range using native cast" do
      in_stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      out_stamp = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
      stamp_range = Framestamp.Range.new!(in_stamp, out_stamp, out_type: :inclusive)

      query =
        Query.from(
          f in fragment(
            "SELECT framestamp_range(?, ?, '[]') as r",
            type(^in_stamp, Framestamp),
            type(^out_stamp, Framestamp)
          ),
          select: f.r
        )

      assert %Postgrex.Range{} = result = Repo.one!(query)
      assert {:ok, ^stamp_range} = Framestamp.Range.load(result)
    end
  end
end
