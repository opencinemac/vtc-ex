defmodule Vtc.Test.Support.Repo.Migrations.AddPostgresTypes do
  @moduledoc false
  use Ecto.Migration

  def change do
    Vtc.Ecto.Postgres.Migrations.migrate()
    Vtc.Ecto.Postgres.Migrations.migrate()
  end
end
