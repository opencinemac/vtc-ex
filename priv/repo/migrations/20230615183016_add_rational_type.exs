defmodule Vtc.Test.Support.Repo.Migrations.AddRationalType do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgRational

  require PgRational.Migrations

  def change do
    PgRational.Migrations.create_all()
  end
end
