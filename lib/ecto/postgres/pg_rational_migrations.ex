use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgRational.Migrations do
  @moduledoc """
  Migrations for adding rational types, functions and constraints to a
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
  CREATE TYPE public.rational AS (
    numerator bigint,
    denominator bigint
  );

  ## Examples

  ```elixir
  defmodule MyMigration do
    use Ecto.Migration

    alias Vtc.Ecto.Postgres.PgRational
    require PgRational.Migrations

    def change do
      PgRational.Migrations.create_all()
    end
  end
  ```
  """
  @spec create_all() :: :ok
  def create_all do
    :ok = create_type()

    :ok
  end

  @doc section: :migrations_types
  @doc """
  Adds `rational` composite type.
  """
  @spec create_type() :: :ok
  def create_type do
    :ok =
      Migration.execute("""
        DO $$ BEGIN
          CREATE TYPE rational AS (
            numerator bigint,
            denominator bigint
          );
          EXCEPTION WHEN duplicate_object
            THEN null;
        END $$;
      """)

    :ok
  end

  @doc section: :migrations_constraints
  @doc """
  Creates basic constraints for a `PgRational` database field.

  ## Constraints created:

  - `{field_name}_denominator_positive`: Checks that the denominator of the field is
    positive.

  ## Examples

  ```elixir
  create table("rationals", primary_key: false) do
    add(:id, :uuid, primary_key: true, null: false)
    add(:a, PgRational.type())
    add(:b, PgRational.type())
  end

  PgRational.migration_add_field_constraints(:rationals, :a)
  PgRational.migration_add_field_constraints(:rationals, :b)
  ```
  """
  @spec create_field_constraints(atom(), atom()) :: :ok
  def create_field_constraints(table, field_name) do
    Migration.create(
      Migration.constraint(
        table,
        "#{field_name}_denominator_positive",
        check: """
        (#{field_name}).denominator > 0
        """
      )
    )

    :ok
  end
end
