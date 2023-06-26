use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgTimecode.Migrations do
  @moduledoc """
  Migrations for adding timecode types, functions and constraints to a
  Postgres database.
  """
  alias Ecto.Migration

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
  CREATE TYPE timecode AS (
    seconds rational,
    rate framerate
  );
  ```

  ## Schemas Created

  Up to two schemas are created as detailed by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgTimecode.Migrations.html#create_all/0-configuring-database-objects)
  section below.

  ## Configuring Database Objects

  To change where supporting functions are created, add the following to your
  Repo confiugration:

  ```elixir
  config :vtc, Vtc.Test.Support.Repo,
    adapter: Ecto.Adapters.Postgres,
    ...
    vtc: [
      pg_timecode: [
        functions_schema: :timecode,
        functions_private_schema: :timecode_private,
        functions_prefix: "timecode"
      ]
    ]
  ```

  Option definitions are as follows:

  - `functions_schema`: The schema for "public" functions that will have backwards
    compatibility guarantees and application code support. Default: `:public`.

  - `functions_private_schema:` The schema for for developer-only "private" functions
    that support the functions in the "timecode" schema. Will NOT have backwards
    compatibility guarantees NOR application code support. Default: `:public`.

  - `functions_prefix`: A prefix to add before all functions. Defaults to "timecode"
    for any function created in the "public" schema, and "" otherwise.

  ## Examples

  ```elixir
  defmodule MyMigration do
    use Ecto.Migration

    alias Vtc.Ecto.Postgres.PgTimecode
    require PgTimecode.Migrations

    def change do
      PgTimecode.Migrations.create_all()
    end
  end
  ```
  """
  @spec create_all() :: :ok
  def create_all do
    :ok = create_type_timecode()
    :ok = create_function_schemas()

    :ok
  end

  @doc section: :migrations_types
  @doc """
  Adds `timecode` composite type.
  """
  @spec create_type_timecode() :: :ok
  def create_type_timecode do
    :ok =
      Migration.execute("""
        DO $$ BEGIN
          CREATE TYPE timecode AS (
            seconds rational,
            rate framerate
          );
          EXCEPTION WHEN duplicate_object
            THEN null;
        END $$;
      """)

    :ok
  end

  @doc section: :migrations_types
  @doc """
  Creates schemas to act as namespaces for rational functions:

  - `timecode`: for user-facing "public" functions that will have backwards
    compatibility guarantees and application code support.

  - `timecode_private`: for developer-only "private" functions that support the
    functions in the "timecode" schema. Will NOT have backwards compatibility guarantees
    NOR application code support.

  These schemas can be configured in your Repo settings.
  """
  @spec create_function_schemas() :: :ok
  def create_function_schemas do
    functions_schema = get_config(Migration.repo(), :functions_schema, :public)

    if functions_schema != :public do
      :ok =
        Migration.execute("""
          DO $$ BEGIN
            CREATE SCHEMA #{functions_schema};
            EXCEPTION WHEN duplicate_schema
              THEN null;
          END $$;
        """)
    end

    functions_private_schema = get_config(Migration.repo(), :functions_private_schema, :public)

    if functions_private_schema != :public do
      :ok =
        Migration.execute("""
          DO $$ BEGIN
            CREATE SCHEMA #{functions_private_schema};
            EXCEPTION WHEN duplicate_schema
              THEN null;
          END $$;
        """)
    end

    :ok
  end

  # Fetches PgRational configuration option from `repo`'s configuration.
  @spec get_config(Ecto.Repo.t(), atom(), Keyword.value()) :: Keyword.value()
  defp get_config(repo, opt, default),
    do: repo.config() |> Keyword.get(:vtc, []) |> Keyword.get(:pg_timecode) |> Keyword.get(opt, default)
end
