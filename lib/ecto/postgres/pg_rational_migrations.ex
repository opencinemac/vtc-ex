use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgRational.Migrations do
  @moduledoc """
  Migrations for adding rational types, functions and constraints to a
  Postgres database.
  """
  alias Vtc.Ecto.Postgres

  @doc section: :migrations_full
  @doc """
  Adds raw SQL queries to a migration for for creating the database types, associated
  functions, casts, operators, and operator families.

  This migration included all migraitons under the `PgTypes` and `PgFunctions` headings.

  Safe to run multiple times when new functionality is added in updates to this library.
  Existing values will be skipped.

  ## Types Created

  Calling this macro creates the following type definitions:

  ```sql
  CREATE TYPE public.rational AS (
    numerator bigint,
    denominator bigint
  );
  ```

  ## Schemas Creates

  Two schemas are created to house our native rational functions:

  - `rationals`: Holds "public", user-facing functions.
  - `rationals_helpers`: Holds "private" helper functions our "public" functions in the
    `rationals` schema rely on.

  ## Functions Creates

  See `ecto_functions` section of these docs for details on native database functions
  created.

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
  defmacro create_all do
    quote do
      unquote(__MODULE__).create_type()
      unquote(__MODULE__).create_greatest_common_denominator()
      unquote(__MODULE__).create_simplify()
    end
  end

  @doc section: :migrations_types
  @doc """
  Adds:

  - `rational` composite type
  - `rationals` schema
  - `rationals_helpers` schema
  """
  @spec create_type() :: Macro.t()
  defmacro create_type do
    quote do
      execute("""
        DO $$ BEGIN
          CREATE TYPE rational AS (
            numerator bigint,
            denominator bigint
          );
          EXCEPTION WHEN duplicate_object
            THEN null;
        END $$;
      """)

      execute("""
      DO $$ BEGIN
        CREATE SCHEMA rationals;
        EXCEPTION WHEN duplicate_object
          THEN null;
      END $$;
      """)

      execute("""
      DO $$ BEGIN
        CREATE SCHEMA rationals_helpers;
        EXCEPTION WHEN duplicate_object
          THEN null;
      END $$;
      """)
    end
  end

  @doc section: :migrations_functions
  @doc """
  Adds `rationals_helpers.greatest_common_denominator(a, b)` function that finds the
  greatest common denominator between two bigint values.
  """
  @spec create_greatest_common_denominator() :: Macro.t()
  defmacro create_greatest_common_denominator do
    quote do
      execute(
        Postgres.Utils.create_plpgsql_function(
          :"rationals_helpers.greatest_common_denominator",
          args: [a: :bigint, b: :bigint],
          returns: :bigint,
          declares: [result: :bigint],
          body: """
          SELECT (
            CASE
              WHEN b = 0 THEN ABS(a)
              WHEN a = 0 THEN ABS(b)
              ELSE rationals_helpers.greatest_common_denominator(b, a % b)
            END
          ) INTO result;

          RETURN result;
          """
        )
      )
    end
  end

  @doc section: :migrations_functions
  @doc """
  Adds `rationals_helpers.simplify(rat)` function that simplifies a rational. Used at
  the end of every rational operation to avoid overflows.
  """
  @spec create_simplify() :: Macro.t()
  defmacro create_simplify do
    quote do
      execute(
        Postgres.Utils.create_plpgsql_function(
          :"rationals_helpers.simplify",
          args: [input: :rational],
          returns: :rational,
          declares: [
            gcd: {:bigint, "rationals_helpers.greatest_common_denominator(input.numerator, input.denominator)"},
            denominator: {:bigint, "ABS(input.denominator / gcd)"},
            numerator: {:bigint, "input.numerator / gcd"}
          ],
          body: """
          SELECT (
            CASE
              WHEN input.denominator < 0 THEN numerator * -1
              ELSE numerator
            END
          ) INTO numerator;

          RETURN (numerator, denominator)::rational;
          """
        )
      )
    end
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
  @spec create_field_constraints(atom(), atom()) :: Macro.t()
  defmacro create_field_constraints(table, field_name) do
    quote do
      field_name = unquote(field_name)
      table = unquote(table)

      create(
        constraint(
          table,
          "#{field_name}_denominator_positive",
          check: """
          (#{field_name}).denominator > 0
          """
        )
      )
    end
  end
end
