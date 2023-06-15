defmodule Vtc.Test.Support.Repo.Migrations.AddRationalType do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgRational

  require PgRational

  def change do
    PgRational.migration_add_type()
  end
end
