defmodule Vtc.Test.Support.Repo.Migrations.AddFramerateType do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgFramerate

  def change do
    :ok = PgFramerate.Migrations.create_all()
    :ok = PgFramerate.Migrations.create_all()
  end
end
