use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgRational.Migrations do
  @moduledoc """
  Migrations for adding rational types, functions and constraints to a
  Postgres database.
  """
  alias Ecto.Migration
  alias Vtc.Ecto.Postgres

  require Ecto.Migration

  @doc section: :migrations_full
  @doc """
  Adds raw SQL queries to a migration for creating the database types, associated
  functions, casts, operators, and operator families.

  This migration included all migraitons under the
  [PgTypes](Vtc.Ecto.Postgres.PgRational.Migrations.html#pgtypes) and
  [PgFunctions](Vtc.Ecto.Postgres.PgRational.Migrations.html#pgfunctions)
  headings.

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

  ## Schemas Created

  Two schemas are created to house our native rational functions:

  - `rational`: for user-facing "public" functions that will have backwards
    compatibility guarantees and application code support.

  - `rational_private`: for developer-only "private" functions that support the
    functions in the "rational" schema. Will NOT havr backwards compatibility guarantees
    NOR application code support.

  ## Functions Created

  See [PgFunctions](Vtc.Ecto.Postgres.PgRational.Migrations.html#pgfunctions)
  section of these docs for details on native database functions
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
  @spec create_all() :: :ok
  def create_all do
    :ok = create_type()
    :ok = create_function_schemas()
    :ok = create_greatest_common_denominator()
    :ok = create_simplify()

    :ok
  end

  @doc section: :migrations_types
  @doc """
  Adds:

  - `rational` composite type
  - `rationals` schema
  - `rationals_helpers` schema
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

  @doc section: :migrations_types
  @doc """
  Creates schemas to act as namespaces for rational functions:

  - `rational`: for user-facing "public" functions that will have backwards
    compatibility guarantees and application code support.

  - `rational_private`: for developer-only "private" functions that support the
    functions in the "rational" schema. Will NOT havr backwards compatibility guarantees
    NOR application code support.
  """
  @spec create_function_schemas() :: :ok
  def create_function_schemas do
    :ok =
      Migration.execute("""
        DO $$ BEGIN
          CREATE SCHEMA rational;
          EXCEPTION WHEN duplicate_schema
            THEN null;
        END $$;
      """)

    :ok =
      Migration.execute("""
        DO $$ BEGIN
          CREATE SCHEMA rational_private;
          EXCEPTION WHEN duplicate_schema
            THEN null;
        END $$;
      """)

    :ok
  end

  @doc section: :migrations_functions
  @doc """
  Adds `rational_private.greatest_common_denominator(a, b)` function that finds the
  greatest common denominator between two bigint values.
  """
  @spec create_greatest_common_denominator() :: :ok
  def create_greatest_common_denominator do
    :ok =
      Migration.execute(
        Postgres.Utils.create_plpgsql_function(
          :"rational_private.greatest_common_denominator",
          args: [a: :bigint, b: :bigint],
          returns: :bigint,
          declares: [result: :bigint],
          body: """
          SELECT (
            CASE
              WHEN b = 0 THEN ABS(a)
              WHEN a = 0 THEN ABS(b)
              ELSE rational_private.greatest_common_denominator(b, a % b)
            END
          ) INTO result;

          RETURN result;
          """
        )
      )

    :ok
  end

  @doc section: :migrations_functions
  @doc """
  Adds `rational_private.simplify(rat)` function that simplifies a rational. Used at
  the end of every rational operation to avoid overflows.
  """
  @spec create_simplify() :: :ok
  def create_simplify do
    Migration.execute(
      Postgres.Utils.create_plpgsql_function(
        :"rational_private.simplify",
        args: [input: :rational],
        returns: :rational,
        declares: [
          gcd: {:bigint, "rational_private.greatest_common_denominator(input.numerator, input.denominator)"},
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
