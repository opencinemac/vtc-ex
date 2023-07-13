defmodule Vtc.Test.Support.Repo.Migrations.AddFramestampSchema01 do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Framestamp

  def change do
    create table("framestamps_01", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:a, Framestamp.type())
      add(:b, Framestamp.type())
    end

    PgFramestamp.Migrations.create_field_constraints("framestamps_01", :b)

    create(index("framestamps_01", [:b]))
  end
end
