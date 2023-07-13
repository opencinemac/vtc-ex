defmodule Vtc.Test.Support.Repo.Migrations.AddRationalSchemas do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgRational

  def change do
    create table("rationals_01", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:a, PgRational.type())
      add(:b, PgRational.type())
    end

    create table("rationals_02", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:a, PgRational.type())
      add(:b, PgRational.type())
    end

    PgRational.Migrations.create_field_constraints(:rationals_02, :a)
    PgRational.Migrations.create_field_constraints(:rationals_02, :b)

    create(index("rationals_02", [:b]))
  end
end
