use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramestamp.Migrations do
  @moduledoc """
  Migrations for adding framestamp types, functions and constraints to a
  Postgres database.
  """
  alias Ecto.Migration
  alias Vtc.Ecto.Postgres
  alias Vtc.Ecto.Postgres.PgFramerate
  alias Vtc.Ecto.Postgres.PgRational

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
  CREATE TYPE framestamp AS (
    seconds rational,
    rate framerate
  );
  ```

  ## Schemas Created

  Up to two schemas are created as detailed by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#create_all/0-configuring-database-objects)
  section below.

  ## Configuring Database Objects

  To change where supporting functions are created, add the following to your
  Repo confiugration:

  ```elixir
  config :vtc, Vtc.Test.Support.Repo,
    adapter: Ecto.Adapters.Postgres,
    ...
    vtc: [
      pg_framestamp: [
        functions_schema: :framestamp,
        functions_private_schema: :framestamp_private,
        functions_prefix: "framestamp"
      ]
    ]
  ```

  Option definitions are as follows:

  - `functions_schema`: The schema for "public" functions that will have backwards
    compatibility guarantees and application code support. Default: `:public`.

  - `functions_private_schema:` The schema for for developer-only "private" functions
    that support the functions in the "framestamp" schema. Will NOT have backwards
    compatibility guarantees NOR application code support. Default: `:public`.

  - `functions_prefix`: A prefix to add before all functions. Defaults to "framestamp"
    for any function created in the "public" schema, and "" otherwise.

  ## Examples

  ```elixir
  defmodule MyMigration do
    use Ecto.Migration

    alias Vtc.Ecto.Postgres.PgFramestamp
    require PgFramestamp.Migrations

    def change do
      PgFramestamp.Migrations.create_all()
    end
  end
  ```
  """
  @spec create_all() :: :ok
  def create_all do
    create_type_framestamp()
    create_function_schemas()

    create_func_with_seconds()

    create_func_eq()
    create_func_neq()
    create_func_strict_eq()
    create_func_strict_neq()
    create_func_lt()
    create_func_lte()
    create_func_gt()
    create_func_gte()
    create_func_cmp()

    create_op_eq()
    create_op_neq()
    create_op_neq2()
    create_op_strict_eq()
    create_op_strict_neq()
    create_op_lt()
    create_op_lte()
    create_op_gt()
    create_op_gte()

    create_op_class_btree()
  end

  @doc section: :migrations_types
  @doc """
  Adds `framestamp` composite type.
  """
  @spec create_type_framestamp() :: :ok
  def create_type_framestamp do
    Migration.execute("""
      DO $$ BEGIN
        CREATE TYPE framestamp AS (
          seconds rational,
          rate framerate
        );
        EXCEPTION WHEN duplicate_object
          THEN null;
      END $$;
    """)
  end

  @doc section: :migrations_types
  @doc """
  Up to two schemas are created as detailed by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#create_all/0-configuring-database-objects)
  section above.
  """
  @spec create_function_schemas() :: :ok
  def create_function_schemas do
    functions_schema = Postgres.Utils.get_type_config(Migration.repo(), :pg_framestamp, :functions_schema, :public)

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
      Postgres.Utils.get_type_config(Migration.repo(), :pg_framestamp, :functions_private_schema, :public)

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
  Creates `framestamp_private.new(seconds, rate)` that rounds `seconds` to the
  nearest whole frame based on `rate` and returns a constructed framestamp.
  """
  @spec create_func_with_seconds() :: :ok
  def create_func_with_seconds do
    rational_round = PgRational.Migrations.function(:round, Migration.repo())

    create_func =
      Postgres.Utils.create_plpgsql_function(
        function(:with_seconds, Migration.repo()),
        args: [seconds: :rational, rate: :framerate],
        declares: [rounded: :bigint],
        returns: :framestamp,
        body: """
        SELECT #{rational_round}((rate).playback * seconds) INTO rounded;
        RETURN (((rounded, 1)::rational / (rate).playback), rate);
        """
      )

    Migration.execute(create_func)
  end

  ## COMPARISON BACKING FUNCTION

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp_private.eq(a, b)` that backs the `=` operator.
  """
  @spec create_func_eq() :: :ok
  def create_func_eq do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:eq, Migration.repo()),
        args: [a: :framestamp, b: :framestamp],
        returns: :boolean,
        body: """
        RETURN (a).seconds = (b.seconds);
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp_private.strict_eq(a, b)` that backs the `===` operator.
  """
  @spec create_func_strict_eq() :: :ok
  def create_func_strict_eq do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:strict_eq, Migration.repo()),
        args: [a: :framestamp, b: :framestamp],
        returns: :boolean,
        body: """
        RETURN (a).seconds = (b.seconds)
          AND (a).rate.playback = (b).rate.playback
          AND (a).rate.tags <@ (b).rate.tags
          AND (a).rate.tags @> (b).rate.tags;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp_private.neq(a, b)` that backs the `<>` operator.
  """
  @spec create_func_neq() :: :ok
  def create_func_neq do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:neq, Migration.repo()),
        args: [a: :framestamp, b: :framestamp],
        returns: :boolean,
        body: """
        RETURN (a).seconds <> (b.seconds);
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp_private.strict_neq(a, b)` that backs the `!===` operator.
  """
  @spec create_func_strict_neq() :: :ok
  def create_func_strict_neq do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:strict_neq, Migration.repo()),
        args: [a: :framestamp, b: :framestamp],
        returns: :boolean,
        body: """
        RETURN (a).seconds <> (b.seconds)
          OR (a).rate.playback <> (b).rate.playback
          OR NOT (a).rate.tags <@ (b).rate.tags
          OR NOT (a).rate.tags @> (b).rate.tags;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp_private.lt(a, b)` that backs the `<` operator.
  """
  @spec create_func_lt() :: :ok
  def create_func_lt do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:lt, Migration.repo()),
        args: [a: :framestamp, b: :framestamp],
        returns: :boolean,
        body: """
        RETURN (a).seconds < (b).seconds;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp_private.lte(a, b)` that backs the `<=` operator.
  """
  @spec create_func_lte() :: :ok
  def create_func_lte do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:lte, Migration.repo()),
        args: [a: :framestamp, b: :framestamp],
        returns: :boolean,
        body: """
        RETURN (a).seconds <= (b).seconds;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp_private.gt(a, b)` that backs the `>` operator.
  """
  @spec create_func_gt() :: :ok
  def create_func_gt do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:gt, Migration.repo()),
        args: [a: :framestamp, b: :framestamp],
        returns: :boolean,
        body: """
        RETURN (a).seconds > (b).seconds;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp_private.gte(a, b)` that backs the `>=` operator.
  """
  @spec create_func_gte() :: :ok
  def create_func_gte do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:gte, Migration.repo()),
        args: [a: :framestamp, b: :framestamp],
        returns: :boolean,
        body: """
        RETURN (a).seconds >= (b).seconds;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp_private.cmp(a, b)` used in the PgTimecode b-tree operator class.
  """
  @spec create_func_cmp() :: :ok
  def create_func_cmp do
    rational_cmp = PgRational.Migrations.private_function(:cmp, Migration.repo())

    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:cmp, Migration.repo()),
        args: [a: :framestamp, b: :framestamp],
        returns: :integer,
        body: """
        RETURN #{rational_cmp}((a).seconds, (b).seconds);
        """
      )

    Migration.execute(create_func)
  end

  ### COMPARISON OPERATORS

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `=` operator that returns true if the
  real-world seconds values for both framestamps are equal.
  """
  @spec create_op_eq() :: :ok
  def create_op_eq do
    create_op =
      Postgres.Utils.create_operator(
        :=,
        :framestamp,
        :framestamp,
        private_function(:eq, Migration.repo()),
        commutator: :=,
        negator: :<>
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `===` operator that returns true if *both*
  the real-world seconds values *and* the framerates for both framestamps are equal.
  """
  @spec create_op_strict_eq() :: :ok
  def create_op_strict_eq do
    create_op =
      Postgres.Utils.create_operator(
        :===,
        :framestamp,
        :framestamp,
        private_function(:strict_eq, Migration.repo()),
        commutator: :===,
        negator: :"!==="
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `<>` operator that returns true if the
  real-world seconds values for both framestamps are not equal.
  """
  @spec create_op_neq() :: :ok
  def create_op_neq do
    create_op =
      Postgres.Utils.create_operator(
        :<>,
        :framestamp,
        :framestamp,
        private_function(:neq, Migration.repo()),
        commutator: :<>,
        negator: :=
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `!=` operator that returns true if the
  real-world seconds values for both framestamps are not equal.
  """
  @spec create_op_neq2() :: :ok
  def create_op_neq2 do
    create_op =
      Postgres.Utils.create_operator(
        :!=,
        :framestamp,
        :framestamp,
        private_function(:neq, Migration.repo()),
        commutator: :!=,
        negator: :=
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `!===` operator that returns true if `a` and
  `b` do not have the same real-world-seconds, framerate playback, or framerate tags.
  """
  @spec create_op_strict_neq() :: :ok
  def create_op_strict_neq do
    create_op =
      Postgres.Utils.create_operator(
        :"!===",
        :framestamp,
        :framestamp,
        private_function(:strict_neq, Migration.repo()),
        commutator: :"!===",
        negator: :===
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `<` operator.
  """
  @spec create_op_lt() :: :ok
  def create_op_lt do
    create_op =
      Postgres.Utils.create_operator(
        :<,
        :framestamp,
        :framestamp,
        private_function(:lt, Migration.repo()),
        commutator: :>,
        negator: :>=
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `<=` operator.
  """
  @spec create_op_lte() :: :ok
  def create_op_lte do
    create_op =
      Postgres.Utils.create_operator(
        :<=,
        :framestamp,
        :framestamp,
        private_function(:lte, Migration.repo()),
        commutator: :>=,
        negator: :>
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `>` operator.
  """
  @spec create_op_gt() :: :ok
  def create_op_gt do
    create_op =
      Postgres.Utils.create_operator(
        :>,
        :framestamp,
        :framestamp,
        private_function(:gt, Migration.repo()),
        commutator: :<,
        negator: :<=
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `>=` operator.
  """
  @spec create_op_gte() :: :ok
  def create_op_gte do
    create_op =
      Postgres.Utils.create_operator(
        :>=,
        :framestamp,
        :framestamp,
        private_function(:gte, Migration.repo()),
        commutator: :<=,
        negator: :<
      )

    Migration.execute(create_op)
  end

  ## OPERATOR CLASSES

  @doc section: :migrations_operator_classes
  @doc """
  Creates a B-tree operator class to support indexing on comparison operations.
  """
  @spec create_op_class_btree() :: :ok
  def create_op_class_btree do
    create_class =
      Postgres.Utils.create_operator_class(
        :framestamp_ops_btree,
        :framestamp,
        :btree,
        [
          <: 1,
          <=: 2,
          =: 3,
          >=: 4,
          >: 5
        ],
        [
          {private_function(:cmp, Migration.repo()), 1}
        ]
      )

    Migration.execute(create_class)
  end

  @doc section: :migrations_constraints
  @doc """
  Creates basic constraints for a [PgFramestamp](`Vtc.Ecto.Postgres.PgFramestamp`) /
  [Framestamp](`Vtc.Framestamp`) database field.

  ## Constraints created:

  - `{field}_rate_positive`: Checks that the playback speed is positive.

  - `{field}_rate_ntsc_tags`: Checks that both `drop` and `non_drop` are not set at the
    same time.

  - `{field}_rate_ntsc_valid`: Checks that NTSC framerates are mathematically sound,
    i.e., that the rate is equal to `(round(rate.playback) * 1000) / 1001`.

  - `{field}_rate_ntsc_drop_valid`: Checks that NTSC, drop-frame framerates are valid,
    i.e, are cleanly divisible by `30_000/1001`.

  - `{field_name}_seconds_divisible_by_rate`: Checks that the `seconds` value of the
    framestamp is cleanly divisible by the `rate.playback` value.

  ## Examples

  ```elixir
  create table("my_table", primary_key: false) do
    add(:id, :uuid, primary_key: true, null: false)
    add(:a, Framestamp.type())
    add(:b, Framestamp.type())
  end

  PgRational.migration_add_field_constraints(:my_table, :a)
  PgRational.migration_add_field_constraints(:my_table, :b)
  ```
  """
  @spec create_field_constraints(atom(), atom()) :: :ok
  def create_field_constraints(table, field) do
    PgFramerate.Migrations.create_field_constraints(table, "(#{field}).rate", :"#{field}_rate")

    seconds_divisible_by_rate =
      Migration.constraint(
        table,
        "#{field}_seconds_divisible_by_rate",
        check: """
        ((#{field}).seconds * (#{field}).rate.playback) % (1, 1)::rational = (0, 1)::rational
        """
      )

    Migration.create(seconds_divisible_by_rate)

    :ok
  end

  @doc """
  Returns the config-qualified name of the function for this type.
  """
  @spec function(atom(), Ecto.Repo.t()) :: String.t()
  def function(name, repo) do
    function_prefix = Postgres.Utils.type_function_prefix(repo, :pg_framestamp)
    "#{function_prefix}#{name}"
  end

  @spec private_function(atom(), Ecto.Repo.t()) :: String.t()
  defp private_function(name, repo) do
    function_prefix = Postgres.Utils.type_private_function_prefix(repo, :pg_framestamp)
    "#{function_prefix}#{name}"
  end
end
