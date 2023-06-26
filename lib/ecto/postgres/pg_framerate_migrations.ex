use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramerate.Migrations do
  @moduledoc """
  Migrations for adding framerate types, functions and constraints to a
  Postgres database.
  """
  alias Ecto.Migration
  alias Ecto.Migration.Constraint

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
  CREATE TYPE framerate_tags AS ENUM (
    'drop',
    'non_drop'
  );
  ```

  ```sql
  CREATE TYPE framerate AS (
    playback rational,
    tags framerate_tags[]
  );
  ```

  ## Schemas Created

  Up to two schemas are created as detailed by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramerate.Migrations.html#create_all/0-configuring-database-objects)
  section below.

  ## Configuring Database Objects

  To change where supporting functions are created, add the following to your
  Repo confiugration:

  ```elixir
  config :vtc, Vtc.Test.Support.Repo,
    adapter: Ecto.Adapters.Postgres,
    ...
    vtc: [
      pg_framerate: [
        functions_schema: :framerate,
        functions_private_schema: :framerate_private,
        functions_prefix: "framerate"
      ]
    ]
  ```

  Option definitions are as follows:

  - `functions_schema`: The schema for "public" functions that will have backwards
    compatibility guarantees and application code support. Default: `:public`.

  - `functions_private_schema:` The schema for for developer-only "private" functions
    that support the functions in the "framerate" schema. Will NOT have backwards
    compatibility guarantees NOR application code support. Default: `:public`.

  - `functions_prefix`: A prefix to add before all functions. Defaults to "framerate"
    for any function created in the "public" schema, and "" otherwise.

  ## Examples

  ```elixir
  defmodule MyMigration do
    use Ecto.Migration

    alias Vtc.Ecto.Postgres.PgFramerate
    require PgFramerate.Migrations

    def change do
      PgFramerate.Migrations.create_all()
    end
  end
  ```
  """
  @spec create_all() :: :ok
  def create_all do
    :ok = create_type_framerate_tags()
    :ok = create_type_framerate()
    :ok = create_function_schemas()

    :ok
  end

  @doc section: :migrations_types
  @doc """
  Adds `framerate_tgs` enum type.
  """
  @spec create_type_framerate_tags() :: :ok
  def create_type_framerate_tags do
    :ok =
      Migration.execute("""
        DO $$ BEGIN
          CREATE TYPE framerate_tags AS ENUM (
            'drop',
            'non_drop'
          );
          EXCEPTION WHEN duplicate_object
            THEN null;
        END $$;
      """)
  end

  @doc section: :migrations_types
  @doc """
  Adds `framerate` composite type.
  """
  @spec create_type_framerate() :: :ok
  def create_type_framerate do
    :ok =
      Migration.execute("""
        DO $$ BEGIN
          CREATE TYPE framerate AS (
            playback rational,
            tags framerate_tags[]
          );
          EXCEPTION WHEN duplicate_object
            THEN null;
        END $$;
      """)

    :ok
  end

  @doc section: :migrations_types
  @doc """
  Creates schemas to act as namespaces for framerate functions:

  - `framerate`: for user-facing "public" functions that will have backwards
    compatibility guarantees and application code support.

  - framerate_private`: for developer-only "private" functions that support the
    functions in the "rational" schema. Will NOT have backwards compatibility guarantees
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

  @doc section: :migrations_constraints
  @doc """
  Creates basic constraints for a [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`)
  database field.

  ## Constraints created:

  - `{field_name}_positive`: Checks that the playback speed is positive.

  - `{field_name}_ntsc_tags`: Checks that only `drop` or `non_drop` is set.

  ## Examples

  ```elixir
  create table("my_table", primary_key: false) do
    add(:id, :uuid, primary_key: true, null: false)
    add(:a, PgFramerate.type())
    add(:b, PgFramerate.type())
  end

  PgRational.migration_add_field_constraints(:my_table, :a)
  PgRational.migration_add_field_constraints(:my_table, :b)
  ```
  """
  @spec create_field_constraints(atom(), atom()) :: :ok
  def create_field_constraints(table, field_name) do
    positive =
      Migration.constraint(
        table,
        "#{field_name}_positive",
        check: """
        (#{field_name}).playback.denominator > 0
        AND (#{field_name}).playback.numerator > 0
        """
      )

    %Constraint{} = Migration.create(positive)

    ntsc_tags =
      Migration.constraint(
        table,
        "#{field_name}_ntsc_tags",
        check: """
        NOT (
          ((#{field_name}).tags) @> '{drop}'::framerate_tags[]
          AND ((#{field_name}).tags) @> '{non_drop}'::framerate_tags[]
        )
        """
      )

    %Constraint{} = Migration.create(ntsc_tags)

    :ok
  end

  # Fetches PgRational configuration option from `repo`'s configuration.
  @spec get_config(Ecto.Repo.t(), atom(), Keyword.value()) :: Keyword.value()
  defp get_config(repo, opt, default),
    do: repo.config() |> Keyword.get(:vtc, []) |> Keyword.get(:pg_framerate) |> Keyword.get(opt, default)
end
