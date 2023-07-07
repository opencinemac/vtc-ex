defmodule Vtc.Test.Support.Repo.Migrations.AddFramestampRangeType do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgFramestamp

  def change do
    :ok = PgFramestamp.Range.Migrations.create_all()
    :ok = PgFramestamp.Range.Migrations.create_all()
  end
end
