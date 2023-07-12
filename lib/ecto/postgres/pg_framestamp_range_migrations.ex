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

  @doc section: :migrations_full
  @doc """
  Adds raw SQL queries to a migration for creating the database types, associated
  functions, casts, operators, and operator families.

  Safe to run multiple times when new functionality is added in updates to this library.
  Existing values will be skipped.

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
  @spec create_all(Keyword.t()) :: :ok
  def create_all(opts \\ []) do
    inject_canonical? = Keyword.get(opts, :inject_canonical?, true)

    create_function_schemas()

    create_func_subtype_diff()
    create_type_framestamp_range()
    create_func_canonical()

    if inject_canonical? do
      inject_canonical_function()
    end

    create_type_framestamp_fastrange()
    create_func_framestamp_fastrange_from_stamps()
    create_func_framestamp_fastrange_from_range()

    :ok
  end

  @doc section: :migrations_types
  @doc """
  Adds `framestamp_range` RANGE type.
  """
  @spec create_type_framestamp_range() :: :ok
  def create_type_framestamp_range do
    subtype_diff = private_function(:subtype_diff, Migration.repo())

    Migration.execute("""
      DO $$ BEGIN
        CREATE TYPE framestamp_range AS RANGE (
          subtype = framestamp,
          subtype_diff = #{subtype_diff}
        );
        EXCEPTION WHEN duplicate_object
          THEN null;
      END $$;
    """)
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
  @spec inject_canonical_function() :: :ok
  def inject_canonical_function do
    canonical = private_function(:canonical, Migration.repo())

    Migration.execute("""
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
    """)
  end

  @doc section: :migrations_types
  @doc """
  Adds `framestamp_fastrange` RANGE type that uses double-precision floats under the
  hood.
  """
  @spec create_type_framestamp_fastrange() :: :ok
  def create_type_framestamp_fastrange do
    Migration.execute("""
      DO $$ BEGIN
        CREATE TYPE framestamp_fastrange AS RANGE (
            subtype = double precision,
            subtype_diff = float8mi
        );
        EXCEPTION WHEN duplicate_object
          THEN null;
      END $$;
    """)
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framestamp_fastrange(:framestamp, framestamp)` to construct fast ranges out
  of framestamps.
  """
  @spec create_func_framestamp_fastrange_from_stamps() :: :ok
  def create_func_framestamp_fastrange_from_stamps do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        "framestamp_fastrange",
        args: [lower: :framestamp, upper: :framestamp],
        returns: :framestamp_fastrange,
        body: """
        RETURN framestamp_fastrange(
          CAST((lower).seconds as double precision),
          CAST((upper).seconds as double precision)
        );
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framestamp_fastrange(:framestamp_range)` to construct fast ranges out
  of the slower `framestamp_range` type.
  """
  @spec create_func_framestamp_fastrange_from_range() :: :ok
  def create_func_framestamp_fastrange_from_range do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        "framestamp_fastrange",
        args: [input: :framestamp_range],
        returns: :framestamp_fastrange,
        body: """
        RETURN framestamp_fastrange(
          CAST((LOWER(input)).seconds as double precision),
          CAST((UPPER(input)).seconds as double precision)
        );
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__subtype_diff(a, b)` used by the range type for more
  efficient GiST indexes.
  """
  @spec create_func_subtype_diff() :: :ok
  def create_func_subtype_diff do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:subtype_diff, Migration.repo()),
        args: [a: :framestamp, b: :framestamp],
        declares: [diff: {:framestamp, "a - b"}],
        returns: :"double precision",
        body: """
        RETURN CAST((diff).seconds as double precision);
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__canonicalization(a, b, type)` used by the range
  constructor to normalize ranges.

  Output ranges have an inclusive lower bound and an exclusive upper bound.
  """
  @spec create_func_canonical() :: :ok
  def create_func_canonical do
    Migration.execute("""
      DO $$ BEGIN
        CREATE TYPE framestamp_range;
        EXCEPTION WHEN duplicate_object
          THEN null;
      END $$;
    """)

    framestamp_with_frames = PgFramestamp.Migrations.function(:with_frames, Migration.repo())
    framestamp_with_seconds = PgFramestamp.Migrations.function(:with_seconds, Migration.repo())

    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:canonical, Migration.repo()),
        args: [input: :framestamp_range],
        declares: [
          single_frame: {:framestamp, "#{framestamp_with_frames}(1, (LOWER(input)).rate)"},
          upper_stamp: {:framestamp, "UPPER(input)"},
          lower_stamp: {:framestamp, "LOWER(input)"},
          rates_match: {:boolean, "(lower_stamp).rate === (upper_stamp).rate"},
          new_rate: :framerate
        ],
        returns: :framestamp_range,
        body: """
        CASE
          WHEN LOWER_INC(input) AND NOT UPPER_INC(input) AND rates_match THEN
            RETURN input;

          WHEN LOWER_INC(input) AND NOT UPPER_INC(input) THEN
            new_rate := GREATEST((lower_stamp).rate, (upper_stamp).rate);
            lower_stamp := #{framestamp_with_seconds}((lower_stamp).seconds, new_rate);
            upper_stamp := #{framestamp_with_seconds}((upper_stamp).seconds, new_rate);
            RETURN framestamp_range(lower_stamp, upper_stamp, '[)');

          WHEN LOWER_INC(input) AND UPPER_INC(input) THEN
            RETURN framestamp_range(lower_stamp, upper_stamp + single_frame, '[)');

          WHEN NOT LOWER_INC(input) AND UPPER_INC(input) THEN
            RETURN framestamp_range(lower_stamp + single_frame, upper_stamp + single_frame, '[)');

          WHEN NOT LOWER_INC(input) AND NOT UPPER_INC(input) THEN
            RETURN framestamp_range(lower_stamp + single_frame, upper_stamp, '[)');

        END CASE;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_types
  @doc """
  Creates function schema as described by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations.html#create_all/0-configuring-database-objects)
  section above.
  """
  @spec create_function_schemas() :: :ok
  def create_function_schemas, do: Postgres.Utils.create_type_schemas(:framestamp_range)

  @spec private_function(atom(), Ecto.Repo.t()) :: String.t()
  defp private_function(name, repo) do
    function_prefix = Postgres.Utils.type_private_function_prefix(repo, :framestamp_range)
    "#{function_prefix}#{name}"
  end
end
