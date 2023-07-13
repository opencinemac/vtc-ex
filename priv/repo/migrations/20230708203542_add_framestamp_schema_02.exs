defmodule Vtc.Test.Support.Repo.Migrations.AddFramestampSchema02 do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Framestamp

  def change do
    create table("framestamps_02", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:a, Framestamp.type(), null: false)
      add(:b, Framestamp.type(), null: false)
    end

    :ok = PgFramestamp.Migrations.create_field_constraints("framestamps_02", :b)

    create(index("framestamps_02", [:b]))

    create(
      index(
        "framestamps_02",
        ["framestamp_range(a, b)"],
        name: :framestamps_a_b_range,
        using: :GIST
      )
    )

    create(
      index(
        "framestamps_02",
        ["framestamp_fastrange(a, b)"],
        name: :framestamps_a_b_fastrange,
        using: :GIST
      )
    )
  end
end
