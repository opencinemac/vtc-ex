defmodule Vtc.Test.Support.Repo.Migrations.AddTimecodeType do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgTimecode

  def change do
    :ok = PgTimecode.Migrations.create_all()
    :ok = PgTimecode.Migrations.create_all()
  end
end
