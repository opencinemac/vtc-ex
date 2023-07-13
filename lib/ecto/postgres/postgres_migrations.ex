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

  - [PgRational](`Vtc.Ecto.Postgres.PgRational.Migrations`).
  - [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate.Migrations`).
  - [PgFramestamp](`Vtc.Ecto.Postgres.PgFramestamp.Migrations`).
  - [PgFramestamp.Range](`Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations`).

  All migrations implement both `up` and `down` functionality, and support rollbacks
  out of the box.

  ## Options

  - `pg_rational_opts`: Options to pass to
    [PgRational.Migrations.create_all/0](`Vtc.Ecto.Postgres.PgRational.Migrations.create_all/0`).

  - `pg_framerate_opts`: Options to pass to
    [PgFramerate.Migrations.create_all/0](`Vtc.Ecto.Postgres.PgFramerate.Migrations.create_all/0`).

  - `pg_framestamp_opts`: Options to pass to
    [PgFramestamp.Migrations.create_all/0](`Vtc.Ecto.Postgres.PgFramestamp.Migrations.create_all/0`).

  - `pg_framestamp_range_opts`: Options to pass to
    [PgFramestamp.Rage.Migrations.create_all/0](`Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations.create_all/0`).

  > #### Required Permissions {: .warning}
  >
  > To add the `framestamp_range`
  > [canonical](https://www.postgresql.org/docs/current/rangetypes.html#RANGETYPES-DISCRETE),
  > function, we must directly add it to the `framestamp_range` type in the `pg_catalog`
  > table. In most databases, this will require elevated permissions. See the
  > `PgFramestamp.Range.Migrations.inject_canonical_function/0` for more information on
  > why this is required.
  >
  > You can choose to skip this step if you wish my setting the `inject_canonical?`
  > op to false, but operations that require discreet nudging of in and out points will
  > not return correct results, and ranges with different upper/lowwer bound types will
  > not be comparable.
  """
  @spec migrate(
          pg_rational_opts: [include: Keyword.t(), exclude: Keyword.t()],
          pg_framerate_opts: [include: Keyword.t(), exclude: Keyword.t()],
          pg_framestamp_opts: [include: Keyword.t(), exclude: Keyword.t()],
          pg_framestamp_range_opts: [include: Keyword.t(), exclude: Keyword.t()]
        ) :: :ok
  def migrate(opts \\ []) do
    pg_rational_opts = Keyword.get(opts, :pg_rational_opts, [])
    pg_framerate_opts = Keyword.get(opts, :pg_framerate_opts, [])
    pg_framestamp_opts = Keyword.get(opts, :pg_framestamp_opts, [])
    pg_framestamp_range_opts = Keyword.get(opts, :pg_framestamp_range_opts, [])

    PgRational.Migrations.create_all(pg_rational_opts)
    PgFramerate.Migrations.create_all(pg_framerate_opts)
    PgFramestamp.Migrations.create_all(pg_framestamp_opts)
    PgFramestamp.Range.Migrations.create_all(pg_framestamp_range_opts)

    :ok
  end
end
