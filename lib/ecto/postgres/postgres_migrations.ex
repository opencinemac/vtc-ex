use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.Migrations do
  @moduledoc """
  Top-level migrations for creating all Vtc ecto types.
  """

  alias Vtc.Ecto.Postgres.PgFramerate
  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Ecto.Postgres.PgTypeMigration

  @doc """
  Runs all migrations. Safe to run multiple times when updates are required.

  Migrations are run for:

  - [PgRational](`Vtc.Ecto.Postgres.PgRational.Migrations`).
  - [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate.Migrations`).
  - [PgFramestamp](`Vtc.Ecto.Postgres.PgFramestamp.Migrations`).
  - [PgFramestamp.Range](`Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations`).

  All migrations implement both `up` and `down` functionality, and support rollbacks
  out of the box.

  ## Options

  - `rational`: Options to pass to
    [PgRational.Migrations.run/0](`Vtc.Ecto.Postgres.PgRational.Migrations.run/0`).

  - `framerate`: Options to pass to
    [PgFramerate.Migrations.run/0](`Vtc.Ecto.Postgres.PgFramerate.Migrations.run/0`).

  - `framestamp`: Options to pass to
    [PgFramestamp.Migrations.run/0](`Vtc.Ecto.Postgres.PgFramestamp.Migrations.run/0`).

  - `framestamp_range`: Options to pass to
    [PgFramestamp.Rage.Migrations.run/0](`Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations.run/0`).

  > #### Required Permissions {: .warning}
  >
  > To add the `framestamp_range`
  > [canonical](https://www.postgresql.org/docs/current/rangetypes.html#RANGETYPES-DISCRETE),
  > function, we must directly add it to the `framestamp_range` type in the `pg_catalog`
  > table. In most databases, this will require elevated permissions. See the
  > `PgFramestamp.Range.Migrations.inject_canonical_function/0` for more information on
  > why this is required.
  >
  > You can choose to skip this step if you wish by setting the `inject_canonical?`
  > op to false, but operations that require discreet nudging of in-and-out points will
  > not return correct results, and ranges with different upper/lower bound types will
  > not be comparable.
  """
  @spec run(
          rational: [include: Keyword.t(atom()), exclude: Keyword.t(atom())],
          framerate: [include: Keyword.t(atom()), exclude: Keyword.t(atom())],
          framestamp: [include: Keyword.t(atom()), exclude: Keyword.t(atom())],
          framestamp_range: [include: Keyword.t(atom()), exclude: Keyword.t(atom())]
        ) :: :ok
  def run(opts \\ []) do
    migrations = [
      PgRational.Migrations,
      PgFramerate.Migrations,
      PgFramestamp.Migrations,
      PgFramestamp.Range.Migrations
    ]

    PgTypeMigration.run_all(migrations, opts)

    :ok
  end
end
