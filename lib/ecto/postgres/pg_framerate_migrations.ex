use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramerate.Migrations do
  @moduledoc """
  Migrations for adding framerate types, functions and constraints to a
  Postgres database.
  """
  alias Ecto.Migration
  alias Vtc.Ecto.Postgres

  require Ecto.Migration

  @typedoc """
  Indicates returned string is an SQL command.
  """
  @type raw_sql() :: String.t()

  @doc section: :migrations_full
  @doc """
  Adds raw SQL queries to a migration for creating the database types, associated
  functions, casts, operators, and operator families.

  This migration included all migraitons under the
  [Pg Types](Vtc.Ecto.Postgres.PgFramerate.Migrations.html#pg-types),
  [Pg Operators](Vtc.Ecto.Postgres.PgFramerate.Migrations.html#pg-operators),
  [Pg Functions](Vtc.Ecto.Postgres.PgFramerate.Migrations.html#pg-functions), and
  [Pg Private Functions](Vtc.Ecto.Postgres.PgFramerate.Migrations.html#pg-private-functions),
  headings.

  Safe to run multiple times when new functionality is added in updates to this library.
  Existing values will be skipped.

  Individual migration functions return raw sql commands in an
  {up_command, down_command} tuple.

  ## Options

  - `include`: A list of migration functions to include. If not set, all sub-migrations
    will be included.

  - `exclude`: A list of migration functions to exclude. If not set, no sub-migrations
    will be excluded.

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
      framerate: [
        functions_schema: :framerate,
        functions_prefix: "framerate"
      ]
    ]
  ```

  Option definitions are as follows:

  - `functions_schema`: The postgres schema to store framerate-related custom functions.

  - `functions_prefix`: A prefix to add before all functions. Defaults to "framestamp"
    for any function created in the `:public` schema, and "" otherwise.

  ## Private Functions

  Some custom function names are prefaced with `__private__`. These functions should
  not be called by end-users, as they are not subject to *any* API stability guarantees.

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
  @spec create_all(include: Keyword.t(), exclude: Keyword.t()) :: :ok
  def create_all(opts \\ []) do
    migrations = [
      &create_type_framerate_tags/0,
      &create_type_framerate/0,
      &create_function_schemas/0,
      &create_func_is_ntsc/0,
      &create_func_strict_eq/0,
      &create_func_strict_neq/0,
      &create_op_strict_eq/0,
      &create_op_strict_neq/0
    ]

    Postgres.Utils.run_migrations(migrations, opts)
  end

  @doc section: :migrations_types
  @doc """
  Adds `framerate_tgs` enum type.
  """
  @spec create_type_framerate_tags() :: {raw_sql(), raw_sql()}
  def create_type_framerate_tags, do: Postgres.Utils.create_type(:framerate_tags, :enum, [:drop, :non_drop])

  @doc section: :migrations_types
  @doc """
  Adds `framerate` composite type.
  """
  @spec create_type_framerate() :: {raw_sql(), raw_sql()}
  def create_type_framerate do
    Postgres.Utils.create_type(:framerate,
      playback: :rational,
      tags: "framerate_tags[]"
    )
  end

  ## FUNCTIONS

  @doc section: :migrations_types
  @doc """
  Creates function schema as described by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramerate.Migrations.html#create_all/0-configuring-database-objects)
  section above.
  """
  @spec create_function_schemas() :: {raw_sql(), raw_sql()}
  def create_function_schemas, do: Postgres.Utils.create_type_schema(:framerate)

  @doc section: :migrations_functions
  @doc """
  Creates `framerate.is_ntsc(rat)` function that returns true if the framerate
  is NTSC drop or non-drop rate.
  """
  @spec create_func_is_ntsc() :: {raw_sql(), raw_sql()}
  def create_func_is_ntsc do
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
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framerate.__private__strict_eq(a, b)` that backs the `===` operator.
  """
  @spec create_func_strict_eq() :: {raw_sql(), raw_sql()}
  def create_func_strict_eq do
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
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framerate.__private__strict_eq(a, b)` that backs the `===` operator.
  """
  @spec create_func_strict_neq() :: {raw_sql(), raw_sql()}
  def create_func_strict_neq do
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
  end

  ## OPERATORS

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framerate, :framerate `===` operator that returns true if *both*
  the playback rate AND tags of a framerate are equal.
  """
  @spec create_op_strict_eq() :: {raw_sql(), raw_sql()}
  def create_op_strict_eq do
    Postgres.Utils.create_operator(
      :===,
      :framerate,
      :framerate,
      private_function(:strict_eq, Migration.repo()),
      commutator: :===,
      negator: :"!==="
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framerate, :framerate `===` operator that returns true if *both*
  the playback rate AND tags of a framerate are equal.
  """
  @spec create_op_strict_neq() :: {raw_sql(), raw_sql()}
  def create_op_strict_neq do
    Postgres.Utils.create_operator(
      :"!===",
      :framerate,
      :framerate,
      private_function(:strict_neq, Migration.repo()),
      commutator: :"!===",
      negator: :===
    )
  end

  ## CONSTRAINTS

  @typedoc """
  SQL value that can be passed as an atom or a string.
  """
  @type sql_value() :: String.t() | atom()

  @typedoc """
  Opts for `create_constraints/3`.
  """
  @type constraint_opt() ::
          {:check_value, sql_value()}
          | {:create_positive?, boolean()}
          | {:create_ntsc_tags?, boolean()}
          | {:create_ntsc_valid?, boolean()}
          | {:create_ntsc_drop_valid?, boolean()}

  @doc section: :migrations_constraints
  @doc """
  Creates basic constraints for a [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`) /
  [Framerate](`Vtc.Framerate`) database field.

  ## Arguments

  - `table`: The table to make the constraint on.

  - `field`: The name of the field being validated.

  ## Options

  - `check_value`: The target value to check. If not set, `table.field` will be used.

  - `create_positive?`: `boolean` Add `{field}_positive` constraint (see below).
    Default: `true`.

  - `create_ntsc_tags?`: `boolean` Add `{field}_ntsc_tags` constraint (see below).
    Default: `true`.

  - `create_ntsc_valid?`: `boolean` Add `{field})_ntsc_valid` constraint (see below).
    Default: `true`.

  - `create_ntsc_drop_valid?`: `boolean` Add `{field})_ntsc_drop_valid` constraint
    (see below). Default: `true`.

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
  @spec create_constraints(sql_value(), sql_value(), [constraint_opt()]) :: :ok
  def create_constraints(table, field_name, opts \\ []) do
    table
    |> build_constraint_list(field_name, opts)
    |> Enum.each(&Migration.create(&1))

    :ok
  end

  # Compiles the constraint structs to be created in the database.
  @doc false
  @spec build_constraint_list(sql_value(), sql_value(), [constraint_opt()]) :: [Migration.Constraint.t()]
  def build_constraint_list(table, field_name, opts) do
    check_value = Keyword.get(opts, :check_value, nil)

    {field_name, check_value} =
      if is_nil(check_value) do
        {field_name, "#{table}.#{field_name}"}
      else
        {field_name, check_value}
      end

    constraints = [
      {
        :create_positive?,
        fn ->
          Migration.constraint(
            table,
            "#{field_name}_rate_positive",
            check: """
            (#{check_value}).playback.denominator > 0
            AND (#{check_value}).playback.numerator > 0
            """
          )
        end
      },
      {
        :create_ntsc_tags?,
        fn ->
          Migration.constraint(
            table,
            "#{field_name}_ntsc_tags",
            check: """
            NOT (
              ((#{check_value}).tags) @> '{drop}'::framerate_tags[]
              AND ((#{check_value}).tags) @> '{non_drop}'::framerate_tags[]
            )
            """
          )
        end
      },
      {
        :create_ntsc_valid?,
        fn ->
          Migration.constraint(
            table,
            "#{field_name}_ntsc_valid",
            check: """
            NOT (
              ((#{check_value}).tags) @> '{drop}'::framerate_tags[]
              OR ((#{check_value}).tags) @> '{non_drop}'::framerate_tags[]
            )
            OR (
                (
                  ROUND((#{check_value}).playback) * 1000,
                  1001
                )::rational
                = (#{check_value}).playback
            )
            """
          )
        end
      },
      {
        :create_drop_valid?,
        fn ->
          Migration.constraint(
            table,
            "#{field_name}_ntsc_drop_valid",
            check: """
            NOT (#{check_value}).tags @> '{drop}'::framerate_tags[]
            OR (#{check_value}).playback % (30000, 1001)::rational = (0, 1)::rational
            """
          )
        end
      }
    ]

    constraints
    |> Enum.filter(fn {opt, _} -> Keyword.get(opts, opt, true) end)
    |> Enum.map(fn {_, constraint_builder} -> constraint_builder.() end)
  end

  @doc """
  Returns the config-qualified name of the function for this type.
  """
  @spec function(atom(), Ecto.Repo.t()) :: String.t()
  def function(name, repo), do: "#{Postgres.Utils.type_function_prefix(repo, :framerate)}#{name}"

  # Returns the config-qualified name of the function for this type.
  @spec private_function(atom(), Ecto.Repo.t()) :: String.t()
  defp private_function(name, repo), do: "#{Postgres.Utils.type_private_function_prefix(repo, :framerate)}#{name}"
end
