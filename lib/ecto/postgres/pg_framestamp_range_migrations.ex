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
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramestamp.Range.Migrations.html#create_all/0-configuring-database-objects)
  section below.

  ## Configuring Database Objects

  To change where supporting functions are created, add the following to your
  Repo confiugration:

  ```elixir
  config :vtc, Vtc.Test.Support.Repo,
    adapter: Ecto.Adapters.Postgres,
    ...
    vtc: [
      pg_framestamp_range: [
        functions_schema: :framestamp_range,
        functions_private_schema: :framestamp_range_private,
        functions_prefix: "framestamp_range"
      ]
    ]
  ```

  Option definitions are as follows:

  - `functions_schema`: The schema for "public" functions that will have backwards
    compatibility guarantees and application code support. Default: `:public`.

  - `functions_private_schema:` The schema for for developer-only "private" functions
    that support the functions in the "public" schema. Will NOT have backwards
    compatibility guarantees NOR application code support. Default: `:public`.

  - `functions_prefix`: A prefix to add before all functions. Defaults to
    "framestamp_range" for any function created in the "public" schema, and ""
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
  @spec create_all() :: :ok
  def create_all do
    create_function_schemas()

    create_func_subtype_diff()
    create_type_framestamp_range()
    create_func_canonicalization()

    create_type_framestamp_fastrange()
    create_func_framestamp_fastrange_from_stamps()
    create_func_framestamp_fastrange_from_range()

    # There is a limitation with PL/pgSQL where shell-types cannot be used as either
    # arguments OR return types.
    #
    # However, in the user-facing API flow, the canonical function must be created
    # before the range type with a shell type, then passed to the range type upon
    # construction. Further, ALTER TYPE does not work on range functions out-of-the
    # gate, so we cannot add it later... through the public API.
    #
    # Instead we are going to edit the pg_catalog directly and supply the function
    # after-the-fact ourselves. Since this will all happen in a single transaction
    # it should be functionally equivalent to creating it on the type as part of the
    # initial call.
    canonicalization = private_function(:canonicalization, Migration.repo())

    Migration.execute("""
      UPDATE pg_catalog.pg_range
      SET
          rngcanonical = '#{canonicalization}'::regproc
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
  Creates `framestamp_private.subtype_diff(a, b)` used by the range type for more
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
  Creates `framestamp_private.canonicalization(a, b, type)` used by the range
  constructor to normalize ranges.

  Output ranges have an inclusive lower bound and an exclusive upper bound.
  """
  @spec create_func_canonicalization() :: :ok
  def create_func_canonicalization do
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
        private_function(:canonicalization, Migration.repo()),
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
  Up to two schemas are created as detailed by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgRational.Migrations.html#create_all/0-configuring-database-objects)
  section above.
  """
  @spec create_function_schemas() :: :ok
  def create_function_schemas, do: Postgres.Utils.create_type_schemas(:pg_framestamp_range)

  @spec private_function(atom(), Ecto.Repo.t()) :: String.t()
  defp private_function(name, repo) do
    function_prefix = Postgres.Utils.type_private_function_prefix(repo, :pg_framestamp_range)
    "#{function_prefix}#{name}"
  end
end
