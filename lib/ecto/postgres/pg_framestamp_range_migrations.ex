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
    create_func_canonicalization()

    create_type_framestamp_range()
  end

  @doc section: :migrations_types
  @doc """
  Adds `framestamp_range` composite type.
  """
  @spec create_type_framestamp_range() :: :ok
  def create_type_framestamp_range do
    subtype_diff = private_function(:subtype_diff, Migration.repo())

    # As of now, pl/pgsql functions cannot be used to
    canonicalization = private_function(:canonicalization, Migration.repo())

    Migration.execute("""
      DO $$ BEGIN
        CREATE TYPE framestamp_range AS RANGE (
          subtype = framestamp,
          subtype_diff = #{subtype_diff},
          canonical= #{canonicalization}
        );
        EXCEPTION WHEN duplicate_object
          THEN null;
      END $$;
    """)
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
        declares: [diff: {:rational, "a - b"}],
        returns: :"double precision",
        body: """
        RETURN CAST(diff as double precision);
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
    framestamp_with_frames = PgFramestamp.Migrations.function(:with_frames, Migration.repo())

    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:canonicalization, Migration.repo()),
        args: [input: :framestamp_range, range_type: :text],
        declares: [single_frame: {:framestamp, "#{framestamp_with_frames}(1, (LOWER(input)).rate)"}],
        returns: :framestamp_range,
        body: """
        CASE
          WHEN range_type = '[)' THEN
            RETURN input;
          WHEN range_type = '[]' THEN
            RETURN framestamp_range(LOWER(input), UPPER(INPUT) + single_frame, '[)');
          WHEN range_type = '()' THEN
            RETURN framestamp_range(LOWER(input) + single_frame, UPPER(INPUT), '[)');
          WHEN range_type = '(]' THEN
            RETURN framestamp_range(LOWER(input) + single_frame, UPPER(INPUT) + single_frame, '[)');
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
