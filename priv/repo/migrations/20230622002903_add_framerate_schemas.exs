defmodule Vtc.Test.Support.Repo.Migrations.AddFramerateSchemas do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgFramerate

  def change do
    create table("framerates_01", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:a, PgFramerate.type())
      add(:b, PgFramerate.type())
    end

    :ok = PgFramerate.Migrations.create_field_constraints(:framerates_01, :b)
  end
end
