defmodule Vtc.Test.Support.Repo.Migrations.AddFramestampType do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgFramestamp

  def change do
    :ok = PgFramestamp.Migrations.create_all()
    :ok = PgFramestamp.Migrations.create_all()
  end
end
