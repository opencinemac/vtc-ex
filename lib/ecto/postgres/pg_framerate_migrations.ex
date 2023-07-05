use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramerate.Migrations do
  @moduledoc """
  Migrations for adding framerate types, functions and constraints to a
  Postgres database.
  """
  alias Ecto.Migration
  alias Vtc.Ecto.Postgres

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
    create_type_framerate_tags()
    create_type_framerate()

    create_function_schemas()

    create_func_is_ntsc()
    create_func_strict_eq()
    create_func_strict_neq()

    create_op_strict_eq()
    create_op_strict_neq()
  end

  @doc section: :migrations_types
  @doc """
  Adds `framerate_tgs` enum type.
  """
  @spec create_type_framerate_tags() :: :ok
  def create_type_framerate_tags do
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
  end

  ## FUNCTIONS

  @doc section: :migrations_types
  @doc """
  Up to two schemas are created as detailed by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramerate.Migrations.html#create_all/0-configuring-database-objects)
  section above.
  """
  @spec create_function_schemas() :: :ok
  def create_function_schemas do
    functions_schema = Postgres.Utils.get_type_config(Migration.repo(), :pg_framerate, :functions_schema, :public)

    if functions_schema != :public do
      Migration.execute("""
        DO $$ BEGIN
          CREATE SCHEMA #{functions_schema};
          EXCEPTION WHEN duplicate_schema
            THEN null;
        END $$;
      """)
    end

    functions_private_schema =
      Postgres.Utils.get_type_config(Migration.repo(), :pg_framerate, :functions_private_schema, :public)

    if functions_private_schema != :public do
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
  Creates `framerate_private.is_ntsc(rat)` function that returns true if the framerate
  is and NTSC drop or non-drop rate.
  """
  @spec create_func_is_ntsc() :: :ok
  def create_func_is_ntsc do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        function(:is_ntsc, Migration.repo()),
        args: [input: :framerate],
        returns: :boolean,
        body: """
        RETURN (
          (input).tags @> '{drop}'::framerate_tags[]
          OR (input).tags @> '{non_drop}'::framerate_tags[]
        );
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framerate_private.strict_eq(a, b)` that backs the `===` operator.
  """
  @spec create_func_strict_eq() :: :ok
  def create_func_strict_eq do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:strict_eq, Migration.repo()),
        args: [a: :framerate, b: :framerate],
        returns: :boolean,
        body: """
        RETURN (a).playback = (b).playback
          AND (a).tags <@ (b).tags
          AND (a).tags @> (b).tags;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framerate_private.strict_eq(a, b)` that backs the `===` operator.
  """
  @spec create_func_strict_neq() :: :ok
  def create_func_strict_neq do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:strict_neq, Migration.repo()),
        args: [a: :framerate, b: :framerate],
        returns: :boolean,
        body: """
        RETURN (a).playback != (b).playback
          OR NOT (a).tags <@ (b).tags
          OR NOT (a).tags @> (b).tags;
        """
      )

    Migration.execute(create_func)
  end

  ## OPERATORS

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framerate, :framerate `===` operator that returns true if *both*
  the playback rate AND tags of a framerate are equal.
  """
  @spec create_op_strict_eq() :: :ok
  def create_op_strict_eq do
    create_op =
      Postgres.Utils.create_operator(
        :===,
        :framerate,
        :framerate,
        private_function(:strict_eq, Migration.repo()),
        commutator: :===,
        negator: :"!==="
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framerate, :framerate `===` operator that returns true if *both*
  the playback rate AND tags of a framerate are equal.
  """
  @spec create_op_strict_neq() :: :ok
  def create_op_strict_neq do
    create_op =
      Postgres.Utils.create_operator(
        :"!===",
        :framerate,
        :framerate,
        private_function(:strict_neq, Migration.repo()),
        commutator: :"!===",
        negator: :===
      )

    Migration.execute(create_op)
  end

  ## CONSTRAINTS

  @doc section: :migrations_constraints
  @doc """
  Creates basic constraints for a [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`) /
  [Framerate](`Vtc.Framerate`) database field.

  ## Arguments

  - `table`: The table to make the constraint on.

  - `target_value`: The target value to check. Can be be any sql fragment that resolves
    to a `framerate` value.

  - `field`: The name of the field being validated. Can be omitted if `target_value`
    is itself a field on `table`. This name is not used for anything but the constraint
    names.

  ## Constraints created:

  - `{field}_positive`: Checks that the playback speed is positive.

  - `{field}_ntsc_tags`: Checks that both `drop` and `non_drop` are not set at the same
    time.

  - `{field}_ntsc_valid`: Checks that NTSC framerates are mathematically sound, i.e.,
    that the rate is equal to `(round(rate.playback) * 1000) / 1001`.

  - `{field}_ntsc_drop_valid`: Checks that NTSC, drop-frame framerates are valid, i.e,
    are cleanly divisible by `30_000/1001`.

  ## Examples

  ```elixir
  create table("my_table", primary_key: false) do
    add(:id, :uuid, primary_key: true, null: false)
    add(:a, Framerate.type())
    add(:b, Framerate.type())
  end

  PgRational.migration_add_field_constraints(:my_table, :a)
  PgRational.migration_add_field_constraints(:my_table, :b)
  ```
  """
  @spec create_field_constraints(atom(), atom() | String.t(), atom() | String.t()) :: :ok
  def create_field_constraints(table, target_value, field \\ nil) do
    field =
      case {target_value, field} do
        {target_value, nil} -> target_value
        {_, field} -> field
      end

    positive =
      Migration.constraint(
        table,
        "#{field}_positive",
        check: """
        (#{target_value}).playback.denominator > 0
        AND (#{target_value}).playback.numerator > 0
        """
      )

    Migration.create(positive)

    ntsc_tags =
      Migration.constraint(
        table,
        "#{field}_ntsc_tags",
        check: """
        NOT (
          ((#{target_value}).tags) @> '{drop}'::framerate_tags[]
          AND ((#{target_value}).tags) @> '{non_drop}'::framerate_tags[]
        )
        """
      )

    Migration.create(ntsc_tags)

    ntsc_valid =
      Migration.constraint(
        table,
        "#{field}_ntsc_valid",
        check: """
        NOT #{function(:is_ntsc, Migration.repo())}(#{target_value})
        OR (
            (
              round((#{target_value}).playback.numerator::float / (#{target_value}).playback.denominator::float) * 1000,
              1001
            )::rational
            = (#{target_value}).playback
        )
        """
      )

    Migration.create(ntsc_valid)

    drop_valid =
      Migration.constraint(
        table,
        "#{field}_ntsc_drop_valid",
        check: """
        NOT (#{target_value}).tags @> '{drop}'::framerate_tags[]
        OR (#{target_value}).playback % (30000, 1001)::rational = (0, 1)::rational
        """
      )

    Migration.create(drop_valid)

    :ok
  end

  @doc """
  Returns the config-qualified name of the function for this type.
  """
  @spec function(atom(), Ecto.Repo.t()) :: String.t()
  def function(name, repo), do: "#{Postgres.Utils.type_function_prefix(repo, :pg_framerate)}#{name}"

  # Returns the config-qualified name of the function for this type.
  @spec private_function(atom(), Ecto.Repo.t()) :: String.t()
  defp private_function(name, repo), do: "#{Postgres.Utils.type_private_function_prefix(repo, :pg_framerate)}#{name}"
end
