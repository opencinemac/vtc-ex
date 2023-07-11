use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations do
  @moduledoc """
  Migrations for adding framestamp range types, functions and constraints to a
  Postgres database.
  """
  alias Ecto.Migration
  alias Vtc.Ecto.Postgres
  alias Vtc.Ecto.Postgres.PgFramestamp

  require Ecto.Migration

  @typedoc """
  Indicates returned string is am SQL command.
  """
  @type raw_sql() :: String.t()

  @doc section: :migrations_full
  @doc """
  Adds raw SQL queries to a migration for creating the database types, associated
  functions, casts, operators, and operator families.

  This migration included all migraitons under the
  [Pg Types](Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations.html#pg-types),
  [Pg Operator Classes](Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations.html#pg-operator-classes),
  [Pg Functions](Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations.html#pg-functions), and
  [Pg Private Functions](Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations.html#pg-private-functions),
  headings.

  Safe to run multiple times when new functionality is added in updates to this library.
  Existing values will be skipped.

  Individual migration functions return raw sql commands in an
  {up_command, down_command} tuple.

  ## Options

  - `include`: A list of migration functions to inclide. If not set, all sub-migrations
    will be included.

  - `exclude`: A list of migration functions to exclude. If not set, no sub-migrations
    will be excluded.

  > #### Required Permissions {: .warning}
  >
  > To add the `framestamp_range`
  > [canonical](https://www.postgresql.org/docs/current/rangetypes.html#RANGETYPES-DISCRETE),
  > function, we must directly add it to the `framestamp_range` type in the `pg_catalog`
  > table. In most databases, this will require elevated permissions. See the
  > `inject_canonical_function/0` for more information on why this is required.
  >
  > You can choose to skip this step if you wish my setting the `inject_canonical?`
  > op to false, but operations that require discreet nudging of in and out points will
  > not return correct results, and ranges with different upper/lowwer bound types will
  > not be comparable.

  ## Types Created

  Calling this macro creates the following type definitions:

  ```sql
  CREATE TYPE framestamp_range AS RANGE (
    subtype = framestamp,
    subtype_diff = framestamp_range_private.subtype_diff
    canonical = framestamp_range_private.canonicalization
  );
  ```

  ```sql
  CREATE TYPE framestamp_fastrange AS RANGE (
    subtype = double precision,
    subtype_diff = float8mi
  );
  ```

  ## Schemas Created

  Up to two schemas are created as detailed by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#create_all/0-configuring-database-objects)
  section below.

  ## Configuring Database Objects

  To change where supporting functions are created, add the following to your
  Repo confiugration:

  ```elixir
  config :vtc, Vtc.Test.Support.Repo,
    adapter: Ecto.Adapters.Postgres,
    ...
    vtc: [
      framestamp_range: [
        functions_schema: :framestamp_range,
        functions_prefix: "framestamp_range"
      ]
    ]
  ```

  Option definitions are as follows:

  - `functions_schema`: The postgres schema to store framestamp_range-related custom
     functions.

  - `functions_prefix`: A prefix to add before all functions. Defaults to
    "framestamp_range" for any function created in the `:public` schema, and ""
    otherwise.

  ## Examples

  ```elixir
  defmodule MyMigration do
    use Ecto.Migration

    alias Vtc.Ecto.Postgres.PgFramestamp
    require PgFramestamp.Migrations

    def change do
      PgFramestamp.Range.Migrations.create_all()
    end
  end
  ```
  """
  @spec create_all(include: Keyword.t(), exclude: Keyword.t()) :: :ok
  def create_all(opts \\ []) do
    migrations = [
      &create_function_schemas/0,
      &create_func_subtype_diff/0,
      &create_type_framestamp_range/0,
      &create_func_canonical/0,
      &inject_canonical_function/0,
      &create_type_framestamp_fastrange/0,
      &create_func_framestamp_fastrange_from_stamps/0,
      &create_func_framestamp_fastrange_from_range/0
    ]

    Postgres.Utils.run_migrations(migrations, opts)
  end

  @doc section: :migrations_types
  @doc """
  Adds `framestamp_range` RANGE type.
  """
  @spec create_type_framestamp_range() :: {raw_sql(), raw_sql()}
  def create_type_framestamp_range do
    Postgres.Utils.create_type(:framestamp_range, :range,
      subtype: :framestamp,
      subtype_diff: private_function(:subtype_diff, Migration.repo())
    )
  end

  @doc section: :migrations_types
  @doc """
  There is a limitation with PL/pgSQL where shell-types cannot be used as either
  arguments OR return types.

  However, in the user-facing API flow, the canonical function must be created
  before the range type with a shell type, then passed to the range type upon
  construction. Further, ALTER TYPE does not work on range functions out-of-the
  gate, so we cannot add it later... through the public API.

  Instead this function edits the pg_catalog directly and supply the function
  after-the-fact ourselves. Since this will all happen in a single transaction
  it should be functionally equivalent to creating it on the type as part of the
  initial call.

  > #### Permissions {: .warning}
  >
  > In most databases, directly editing the pg_catalog will require elevated
  > permissions.
  """
  @spec inject_canonical_function() :: {raw_sql(), raw_sql()}
  def inject_canonical_function do
    canonical = private_function(:canonical, Migration.repo())

    {
      """
      UPDATE pg_catalog.pg_range
      SET
          rngcanonical = '#{canonical}'::regproc
      WHERE
          pg_catalog.pg_range.rngcanonical = '-'::regproc
          AND EXISTS (
              SELECT * FROM pg_catalog.pg_type
              WHERE pg_catalog.pg_type.oid = pg_catalog.pg_range.rngsubtype
              AND pg_catalog.pg_type.typname = 'framestamp'
          )
          AND EXISTS (
              SELECT * FROM pg_catalog.pg_type
              WHERE pg_catalog.pg_type.oid = pg_catalog.pg_range.rngtypid
              AND pg_catalog.pg_type.typname = 'framestamp_range'
          );
      """,
      ""
    }
  end

  @doc section: :migrations_types
  @doc """
  Adds `framestamp_fastrange` RANGE type that uses double-precision floats under the
  hood.
  """
  @spec create_type_framestamp_fastrange() :: {raw_sql(), raw_sql()}
  def create_type_framestamp_fastrange do
    Postgres.Utils.create_type(:framestamp_fastrange, :range,
      subtype: "double precision",
      subtype_diff: :float8mi
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framestamp_fastrange(:framestamp, framestamp)` to construct fast ranges out
  of framestamps.
  """
  @spec create_func_framestamp_fastrange_from_stamps() :: {raw_sql(), raw_sql()}
  def create_func_framestamp_fastrange_from_stamps do
    Postgres.Utils.create_plpgsql_function(
      "framestamp_fastrange",
      args: [lower_stamp: :framestamp, upper_stamp: :framestamp],
      returns: :framestamp_fastrange,
      body: """
      RETURN framestamp_fastrange(
        (lower_stamp).__seconds_n::double precision /  (lower_stamp).__seconds_d::double precision,
        (upper_stamp).__seconds_n::double precision /  (upper_stamp).__seconds_d::double precision
      );
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framestamp_fastrange(:framestamp_range)` to construct fast ranges out
  of the slower `framestamp_range` type.
  """
  @spec create_func_framestamp_fastrange_from_range() :: {raw_sql(), raw_sql()}
  def create_func_framestamp_fastrange_from_range do
    Postgres.Utils.create_plpgsql_function(
      "framestamp_fastrange",
      args: [input: :framestamp_range],
      declares: [
        lower_stamp: {:framestamp, "LOWER(input)"},
        upper_stamp: {:framestamp, "UPPER(input)"}
      ],
      returns: :framestamp_fastrange,
      body: """
      RETURN framestamp_fastrange(
        (lower_stamp).__seconds_n::double precision /  (lower_stamp).__seconds_d::double precision,
        (upper_stamp).__seconds_n::double precision /  (upper_stamp).__seconds_d::double precision
      );
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__subtype_diff(a, b)` used by the range type for more
  efficient GiST indexes.
  """
  @spec create_func_subtype_diff() :: {raw_sql(), raw_sql()}
  def create_func_subtype_diff do
    Postgres.Utils.create_plpgsql_function(
      private_function(:subtype_diff, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: [diff: {:framestamp, "a - b"}],
      returns: :"double precision",
      body: """
      RETURN (diff).__seconds_n::double precision /  (diff).__seconds_d::double precision;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__canonicalization(a, b, type)` used by the range
  constructor to normalize ranges.

  Output ranges have an inclusive lower bound and an exclusive upper bound.
  """
  @spec create_func_canonical() :: {raw_sql(), raw_sql()}
  def create_func_canonical do
    framestamp_with_seconds = PgFramestamp.Migrations.function(:with_seconds, Migration.repo())

    Postgres.Utils.create_plpgsql_function(
      private_function(:canonical, Migration.repo()),
      args: [input: :framestamp_range],
      declares: [
        lower_stamp: {:framestamp, "LOWER(input)"},
        upper_stamp: {:framestamp, "UPPER(input)"},
        single_frame: {
          :framestamp,
          """
          (
            (lower_stamp).__rate_d,
            (lower_stamp).__rate_n,
            (lower_stamp).__rate_n,
            (lower_stamp).__rate_d,
            (lower_stamp).__rate_tags
          )
          """
        },
        rates_match: {
          :boolean,
          """
          (upper_stamp).__rate_n = (lower_stamp).__rate_n
          AND (upper_stamp).__rate_d = (lower_stamp).__rate_d
          AND (upper_stamp).__rate_tags <@ (lower_stamp).__rate_tags
          AND (upper_stamp).__rate_tags @> (lower_stamp).__rate_tags
          """
        }
      ],
      returns: :framestamp_range,
      body: """
      CASE
        WHEN LOWER_INC(input) AND NOT UPPER_INC(input) AND rates_match THEN
          RETURN input;

        WHEN LOWER_INC(input) AND NOT UPPER_INC(input) THEN
          RETURN framestamp_range(
            #{framestamp_with_seconds}(
              ((lower_stamp).__seconds_n, (lower_stamp).__seconds_d),
              ((((lower_stamp).__rate_n, (lower_stamp).__rate_d)), (lower_stamp).__rate_tags)
            ),
            #{framestamp_with_seconds}(
              ((upper_stamp).__seconds_n, (upper_stamp).__seconds_d),
              ((((lower_stamp).__rate_n, (lower_stamp).__rate_d)), (lower_stamp).__rate_tags)
            ),
            '[)'
          );

        WHEN LOWER_INC(input) AND UPPER_INC(input) THEN
          RETURN framestamp_range(lower_stamp, upper_stamp + single_frame, '[)');

        WHEN NOT LOWER_INC(input) AND UPPER_INC(input) THEN
          RETURN framestamp_range(lower_stamp + single_frame, upper_stamp + single_frame, '[)');

        WHEN NOT LOWER_INC(input) AND NOT UPPER_INC(input) THEN
          RETURN framestamp_range(lower_stamp + single_frame, upper_stamp, '[)');

      END CASE;
      """
    )
  end

  @doc section: :migrations_types
  @doc """
  Creates function schema as described by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations.html#create_all/0-configuring-database-objects)
  section above.
  """
  @spec create_function_schemas() :: {raw_sql(), raw_sql()}
  def create_function_schemas, do: Postgres.Utils.create_type_schema(:framestamp_range)

  @spec private_function(atom(), Ecto.Repo.t()) :: String.t()
  defp private_function(name, repo) do
    function_prefix = Postgres.Utils.type_private_function_prefix(repo, :framestamp_range)
    "#{function_prefix}#{name}"
  end
end
