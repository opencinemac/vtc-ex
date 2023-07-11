use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.Migrations do
  @moduledoc """
  Top-level migrations for creating all Vtc ecto types.
  """

  alias Vtc.Ecto.Postgres.PgFramerate
  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Ecto.Postgres.PgRational

  @doc """
  Runs all migrations. Safe to run multiple times when updates are required.

  Migrations are run for:

  - [PgRational](`Vtc.Ecto.Postgres.PgRational.Migrations`)
  - [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate.Migrations`)
  - [PgFramestamp](`Vtc.Ecto.Postgres.PgFramestamp.Migrations`)
  - [PgFramestamp.Range](`Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations`)
  """
  @spec migrate() :: :ok
  def migrate do
    PgRational.Migrations.create_all()
    PgFramerate.Migrations.create_all()
    PgFramestamp.Migrations.create_all()
    PgFramestamp.Range.Migrations.create_all()

    :ok
  end
end
