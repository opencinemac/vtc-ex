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

    :ok
  end

  @doc section: :migrations_types
  @spec create_type_framerate_tags() :: :ok
  @doc """
  Adds `framerate_tgs` enum type.
  """
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
end
