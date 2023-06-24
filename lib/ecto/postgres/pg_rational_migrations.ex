use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgRational.Migrations do
  @moduledoc """
  Migrations for adding rational types, casts, functions and constraints to a
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

  Up to two schemas are created as detailed by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgRational.Migrations.html#create_all/0-configuring-database-objects)
  section below.

  ## Configuring Database Objects

  To change where supporting functions are created, add the following to your
  Repo confiugration:

  ```elixir
  config :vtc, Vtc.Test.Support.Repo,
    adapter: Ecto.Adapters.Postgres,
    ...
    vtc: [
      pg_rational: [
        functions_schema: :rational,
        functions_private_schema: :rational_private,
        functions_prefix: "rational"
      ]
    ]
  ```

  Option definitions are as follows:

  - `functions_schema`: The schema for "public" functions that will have backwards
    compatibility guarantees and application code support. Default: `:public`.

  - `functions_private_schema:` The schema for for developer-only "private" functions
    that support the functions in the "rational" schema. Will NOT havr backwards
    compatibility guarantees NOR application code support. Default: `:public`.

  - `functions_prefix`: A prefix to add before all functions. Defaults to "rational" for
    any function created in the "public" schema, and "" otherwise.

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

    :ok = create_func_greatest_common_denominator()
    :ok = create_func_simplify()

    :ok = create_func_minus()
    :ok = create_func_round()
    :ok = create_func_add()
    :ok = create_func_sub()
    :ok = create_func_mult()
    :ok = create_func_div()

    :ok = create_func_cast_to_double_precison()

    :ok = create_op_add()
    :ok = create_op_sub()
    :ok = create_op_mult()
    :ok = create_op_div()

    :ok = create_cast_double_precision()

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

  @doc section: :migrations_functions
  @doc """
  Adds `rational_private.greatest_common_denominator(a, b)` function that finds the
  greatest common denominator between two bigint values.
  """
  @spec create_func_greatest_common_denominator() :: :ok
  def create_func_greatest_common_denominator do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        :"#{private_function_prefix(Migration.repo())}greatest_common_denominator",
        args: [a: :bigint, b: :bigint],
        returns: :bigint,
        declares: [result: :bigint],
        body: """
        SELECT (
          CASE
            WHEN b = 0 THEN ABS(a)
            WHEN a = 0 THEN ABS(b)
            ELSE #{private_function_prefix(Migration.repo())}greatest_common_denominator(b, a % b)
          END
        ) INTO result;

        RETURN result;
        """
      )

    :ok = Migration.execute(create_func)

    :ok
  end

  @doc section: :migrations_functions
  @doc """
  Adds `rational_private.simplify(rat)` function that simplifies a rational. Used at
  the end of every rational operation to avoid overflows.
  """
  @spec create_func_simplify() :: :ok
  def create_func_simplify do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        :"#{private_function_prefix(Migration.repo())}simplify",
        args: [input: :rational],
        returns: :rational,
        declares: [
          gcd:
            {:bigint,
             "#{private_function_prefix(Migration.repo())}greatest_common_denominator(input.numerator, input.denominator)"},
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

    :ok = Migration.execute(create_func)

    :ok
  end

  @doc section: :migrations_functions
  @doc """
  Returns the negated version of the rational
  """
  @spec create_func_minus() :: :ok
  def create_func_minus do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        :"#{function_prefix(Migration.repo())}minus",
        args: [input: :rational],
        returns: :rational,
        body: """
        RETURN ((input).numerator * -1, (input).denominator)::rational;
        """
      )

    :ok = Migration.execute(create_func)

    :ok
  end

  @doc section: :migrations_functions
  @doc """
  Returns the rational input, rounded to the nearest :bigint
  """
  @spec create_func_round() :: :ok
  def create_func_round do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        :"#{function_prefix(Migration.repo())}round",
        args: [input: :rational],
        declares: [result: :bigint],
        returns: :bigint,
        body: """
        SELECT (
          CASE
            WHEN (input).numerator < 0 THEN
              #{function_prefix(Migration.repo())}round(
                #{function_prefix(Migration.repo())}minus(input)
              ) * -1
            WHEN (((input).numerator % (input).denominator) * 2) < (input).denominator THEN
              (input).numerator / (input).denominator
            ELSE
              ((input).numerator / (input).denominator) + 1
          END
        ) INTO result;

        RETURN result;
        """
      )

    :ok = Migration.execute(create_func)

    :ok
  end

  @doc section: :migrations_functions
  @spec create_func_cast_to_double_precison() :: :ok
  def create_func_cast_to_double_precison do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        :"#{private_function_prefix(Migration.repo())}cast_to_float",
        args: [value: :rational],
        returns: :"double precision",
        body: """
        RETURN CAST ((value).numerator AS double precision) / CAST ((value).denominator AS double precision);
        """
      )

    :ok = Migration.execute(create_func)

    :ok
  end

  @doc section: :migrations_functions
  @doc """
  Creates the backing function for the '+' operator between two rationals.
  """
  @spec create_func_add() :: :ok
  def create_func_add do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        :"#{private_function_prefix(Migration.repo())}add",
        args: [a: :rational, b: :rational],
        declares: [
          numerator: {:bigint, "((a).numerator * (b).denominator) + ((b).numerator * (a).denominator)"},
          denominator: {:bigint, "(a).denominator * (b).denominator"},
          result: {:rational, "#{private_function_prefix(Migration.repo())}simplify((numerator, denominator))"}
        ],
        returns: :rational,
        body: """
        RETURN result;
        """
      )

    :ok = Migration.execute(create_func)

    :ok
  end

  @doc section: :migrations_functions
  @doc """
  Creates the backing function for the '-' operator between two rationals.
  """
  @spec create_func_sub() :: :ok
  def create_func_sub do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        :"#{private_function_prefix(Migration.repo())}sub",
        args: [a: :rational, b: :rational],
        declares: [
          b_numerator: {:bigint, "(b).numerator * -1"},
          b_negated: {:rational, "(b_numerator, (b).denominator)"},
          result: {:rational, "#{private_function_prefix(Migration.repo())}add(a, b_negated)"}
        ],
        returns: :rational,
        body: """
        RETURN result;
        """
      )

    :ok = Migration.execute(create_func)

    :ok
  end

  @doc section: :migrations_functions
  @doc """
  Creates the backing function for the '*' operator between two rationals.
  """
  @spec create_func_mult() :: :ok
  def create_func_mult do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        :"#{private_function_prefix(Migration.repo())}mult",
        args: [a: :rational, b: :rational],
        declares: [
          numerator: {:bigint, "(a).numerator * (b).numerator"},
          denominator: {:bigint, "(a).denominator * (b).denominator"},
          result: {:rational, "#{private_function_prefix(Migration.repo())}simplify((numerator, denominator))"}
        ],
        returns: :rational,
        body: """
        RETURN result;
        """
      )

    :ok = Migration.execute(create_func)

    :ok
  end

  @doc section: :migrations_functions
  @doc """
  Creates the backing function for the '*' operator between two rationals.
  """
  @spec create_func_div() :: :ok
  def create_func_div do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        :"#{private_function_prefix(Migration.repo())}div",
        args: [a: :rational, b: :rational],
        declares: [
          numerator: {:bigint, "(a).numerator * (b).denominator"},
          denominator: {:bigint, "(a).denominator * (b).numerator"},
          result: {:rational, "#{private_function_prefix(Migration.repo())}simplify((numerator, denominator))"}
        ],
        returns: :rational,
        body: """
        RETURN result;
        """
      )

    :ok = Migration.execute(create_func)

    :ok
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational + operator.
  """
  @spec create_op_add() :: :ok
  def create_op_add do
    create_op =
      Postgres.Utils.create_operator(
        :+,
        :rational,
        :rational,
        :"#{private_function_prefix(Migration.repo())}add"
      )

    :ok = Migration.execute(create_op)

    :ok
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational + operator.
  """
  @spec create_op_sub() :: :ok
  def create_op_sub do
    create_op =
      Postgres.Utils.create_operator(
        :-,
        :rational,
        :rational,
        :"#{private_function_prefix(Migration.repo())}sub"
      )

    :ok = Migration.execute(create_op)

    :ok
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational * operator.
  """
  @spec create_op_mult() :: :ok
  def create_op_mult do
    create_op =
      Postgres.Utils.create_operator(
        :*,
        :rational,
        :rational,
        :"#{private_function_prefix(Migration.repo())}mult"
      )

    :ok = Migration.execute(create_op)

    :ok
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational * operator.
  """
  @spec create_op_div() :: :ok
  def create_op_div do
    create_op =
      Postgres.Utils.create_operator(
        :/,
        :rational,
        :rational,
        :"#{private_function_prefix(Migration.repo())}div"
      )

    :ok = Migration.execute(create_op)

    :ok
  end

  @doc section: :migrations_casts
  @doc """
  Creates a native cast for:

  ```sql
  rational AS double precision
  ```
  """
  @spec create_cast_double_precision() :: :ok
  def create_cast_double_precision do
    create_cast =
      Postgres.Utils.create_cast(
        :rational,
        :"double precision",
        :"#{private_function_prefix(Migration.repo())}cast_to_float"
      )

    :ok = Migration.execute(create_cast)

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

  # Fetches PgRational configuration option from `repo`'s configuration.
  @spec get_config(Ecto.Repo.t(), atom(), Keyword.value()) :: Keyword.value()
  defp get_config(repo, opt, default),
    do: repo.config() |> Keyword.get(:vtc, []) |> Keyword.get(:pg_rational) |> Keyword.get(opt, default)

  @spec private_function_prefix(Ecto.Repo.t()) :: String.t()
  defp private_function_prefix(repo) do
    functions_private_schema = get_config(repo, :functions_private_schema, :public)
    functions_prefix = get_config(repo, :functions_prefix, "")

    functions_prefix =
      if functions_prefix == "" and functions_private_schema == :public, do: "rational", else: functions_prefix

    functions_prefix = if functions_prefix == "", do: "", else: "#{functions_prefix}_"

    "#{functions_private_schema}.#{functions_prefix}"
  end

  @spec function_prefix(Ecto.Repo.t()) :: String.t()
  defp function_prefix(repo) do
    functions_schema = get_config(repo, :functions_schema, :public)
    functions_prefix = get_config(repo, :functions_prefix, "")

    functions_prefix = if functions_prefix == "" and functions_schema == :public, do: "rational", else: functions_prefix

    functions_prefix = if functions_prefix == "", do: "", else: "#{functions_prefix}_"

    "#{functions_schema}.#{functions_prefix}"
  end
end
