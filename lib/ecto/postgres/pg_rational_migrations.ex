use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgRational.Migrations do
  @moduledoc """
  Migrations for adding rational types, casts, functions and constraints to a
  Postgres database.
  """
  alias Ecto.Migration
  alias Ecto.Migration.Constraint
  alias Vtc.Ecto.Postgres

  require Ecto.Migration

  @doc section: :migrations_full
  @doc """
  Adds raw SQL queries to a migration for creating the database types, associated
  functions, casts, operators, and operator families.

  This migration included all migraitons under the
  [Pg Types](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-types),
  [Pg Operators](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-operators),
  [Pg Operator Classes](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-operator-classes),
  [Pg Functions](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-functions), and
  [Pg Private Functions](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-private-functions),
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

  ## Operators Created

  See [PgOperators](Vtc.Ecto.Postgres.PgRational.Migrations.html#pgoperators)
  section of these docs for details on native database operators
  created.

  ## Casts Created

  See [PgCasts](Vtc.Ecto.Postgres.PgRational.Migrations.html#pgcasts)
  section of these docs for details on native database operators
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
    create_type()
    create_function_schemas()

    create_func_greatest_common_denominator()
    create_func_simplify()

    create_func_minus()
    create_func_abs()
    create_func_round()
    create_func_floor()
    create_func_add()
    create_func_sub()
    create_func_mult()
    create_func_div()
    create_func_floor_div()
    create_func_modulo()

    create_op_add()
    create_op_sub()
    create_op_mult()
    create_op_div()
    create_op_modulo()

    create_func_cmp()
    create_func_eq()
    create_func_neq()
    create_func_lt()
    create_func_lte()
    create_func_gt()
    create_func_gte()

    create_op_eq()
    create_op_neq()
    create_op_neq2()
    create_op_lt()
    create_op_lte()
    create_op_gt()
    create_op_gte()
    create_op_class_btree()

    create_func_cast_to_double_precison()
    create_cast_double_precision()
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
  end

  @doc section: :migrations_types
  @doc """
  Up to two schemas are created as detailed by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgRational.Migrations.html#create_all/0-configuring-database-objects)
  section above.
  """
  @spec create_function_schemas() :: :ok
  def create_function_schemas, do: Postgres.Utils.create_type_schemas(:pg_rational)

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.greatest_common_denominator(a, b)` function that finds the
  greatest common denominator between two bigint values.
  """
  @spec create_func_greatest_common_denominator() :: :ok
  def create_func_greatest_common_denominator do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:greatest_common_denominator, Migration.repo()),
        args: [a: :bigint, b: :bigint],
        returns: :bigint,
        body: """
        CASE
          WHEN b = 0 THEN
            RETURN ABS(a);
          WHEN a = 0 THEN
            RETURN ABS(b);
          ELSE
            RETURN #{private_function(:greatest_common_denominator, Migration.repo())}(b, a % b);
        END CASE;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.simplify(rat)` function that simplifies a rational. Used at
  the end of every rational operation to avoid overflows.
  """
  @spec create_func_simplify() :: :ok
  def create_func_simplify do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:simplify, Migration.repo()),
        args: [input: :rational],
        returns: :rational,
        declares: [
          gcd:
            {:bigint,
             "#{private_function(:greatest_common_denominator, Migration.repo())}(input.numerator, input.denominator)"},
          denominator: {:bigint, "ABS(input.denominator / gcd)"},
          numerator: {:bigint, "input.numerator / gcd"}
        ],
        body: """
        IF (input).denominator < 0 THEN
          RETURN  (numerator * -1, denominator);
        ELSE
          RETURN (numerator, denominator);
        END IF;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_functions
  @doc """
  Creates `rational.minus(rat)` function that flips the sign of the input value --
  makes a positive value negative and a negative value positive.
  """
  @spec create_func_minus() :: :ok
  def create_func_minus do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        function(:minus, Migration.repo()),
        args: [input: :rational],
        returns: :rational,
        body: """
        RETURN ((input).numerator * -1, (input).denominator)::rational;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_functions
  @doc """
  Creates `ABS(rational)` function that returns the absolute value of the rational
  value.
  """
  @spec create_func_abs() :: :ok
  def create_func_abs do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        "ABS",
        args: [input: :rational],
        returns: :rational,
        body: """
        RETURN (ABS((input).numerator), ABS((input).denominator))::rational;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_functions
  @doc """
  Creates `ROUND(rational)` function that returns the rational input, rounded to the
  nearest :bigint.
  """
  @spec create_func_round() :: :ok
  def create_func_round do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        "ROUND",
        args: [input: :rational],
        returns: :bigint,
        body: """
        CASE
          WHEN (input).numerator < 0 THEN
            input := #{function(:minus, Migration.repo())}(input);
            RETURN ROUND(input) * -1;
          WHEN (((input).numerator % (input).denominator) * 2) < (input).denominator THEN
            RETURN (input).numerator / (input).denominator;
          ELSE
            RETURN ((input).numerator / (input).denominator) + 1;
        END CASE;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_functions
  @doc """
  Creates `FLOOR(rational)` function that returns the rational input as a `bigint`,
  rounded towards zero, to match Postgres `FLOOR(real)` behavior.
  """
  @spec create_func_floor() :: :ok
  def create_func_floor do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        "FLOOR",
        args: [input: :rational],
        returns: :bigint,
        body: """
        RETURN ((input).numerator / (input).denominator);
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates a native CAST from `rational` to `double precision`.
  """
  @spec create_func_cast_to_double_precison() :: :ok
  def create_func_cast_to_double_precison do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:cast_to_double, Migration.repo()),
        args: [value: :rational],
        returns: :"double precision",
        body: """
        RETURN CAST ((value).numerator AS double precision) / CAST ((value).denominator AS double precision);
        """
      )

    Migration.execute(create_func)
  end

  ## ARITHMATIC BACKING FUNCS

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.add(a, b)` backing function for the `+` operator
  between two rationals.
  """
  @spec create_func_add() :: :ok
  def create_func_add do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:add, Migration.repo()),
        args: [a: :rational, b: :rational],
        declares: [
          numerator: {:bigint, "((a).numerator * (b).denominator) + ((b).numerator * (a).denominator)"},
          denominator: {:bigint, "(a).denominator * (b).denominator"}
        ],
        returns: :rational,
        body: """
        RETURN #{private_function(:simplify, Migration.repo())}((numerator, denominator));
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.sub(a, b)` backing function for the `-` operator
  between two rationals.
  """
  @spec create_func_sub() :: :ok
  def create_func_sub do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:sub, Migration.repo()),
        args: [a: :rational, b: :rational],
        declares: [
          b_numerator: {:bigint, "(b).numerator * -1"},
          b_negated: {:rational, "(b_numerator, (b).denominator)"}
        ],
        returns: :rational,
        body: """
        RETURN #{private_function(:add, Migration.repo())}(a, b_negated);
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.mult(a, b)` backing function for the `*` operator
  between two rationals.
  """
  @spec create_func_mult() :: :ok
  def create_func_mult do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:mult, Migration.repo()),
        args: [a: :rational, b: :rational],
        declares: [
          numerator: {:bigint, "(a).numerator * (b).numerator"},
          denominator: {:bigint, "(a).denominator * (b).denominator"}
        ],
        returns: :rational,
        body: """
        RETURN #{private_function(:simplify, Migration.repo())}((numerator, denominator));
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.div(a, b)` backing function for the `/` operator
  between two rationals.
  """
  @spec create_func_div() :: :ok
  def create_func_div do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:div, Migration.repo()),
        args: [a: :rational, b: :rational],
        declares: [
          numerator: {:bigint, "(a).numerator * (b).denominator"},
          denominator: {:bigint, "(a).denominator * (b).numerator"}
        ],
        returns: :rational,
        body: """
        RETURN #{private_function(:simplify, Migration.repo())}((numerator, denominator));
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.div(a, b)` backing function for the `/` operator
  between two rationals.
  """
  @spec create_func_floor_div() :: :ok
  def create_func_floor_div do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        "DIV",
        args: [a: :rational, b: :rational],
        declares: [result: {:rational, "a / b"}],
        returns: :bigint,
        body: """
        RETURN FLOOR(result);
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.modulo(a, b)` backing function for the `%` operator
  between two rationals.
  """
  @spec create_func_modulo() :: :ok
  def create_func_modulo do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:modulo, Migration.repo()),
        args: [dividend: :rational, divisor: :rational],
        declares: [
          numerator:
            {:bigint,
             """
             ((dividend).numerator * (divisor).denominator)
             % ((divisor).numerator * (dividend).denominator)
             """},
          denominator: {:bigint, "(dividend).denominator * (divisor).denominator"}
        ],
        returns: :rational,
        body: """
        RETURN #{private_function(:simplify, Migration.repo())}((numerator, denominator));
        """
      )

    Migration.execute(create_func)
  end

  ## COMPARISON BACKING FUNCS

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.cmp(a, b)` that returns:

    - `1` if a > b
    - `0` if a == b
    - `-1` if a < b

  Used to back equality operators.
  """
  @spec create_func_cmp() :: :ok
  def create_func_cmp do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:cmp, Migration.repo()),
        args: [a: :rational, b: :rational],
        declares: [
          a_cmp: {:bigint, "((a).numerator * (b).denominator)"},
          b_cmp: {:bigint, "((b).numerator * (a).denominator)"}
        ],
        returns: :integer,
        body: """
        CASE
          WHEN a_cmp > b_cmp THEN
            RETURN 1;
          WHEN a_cmp < b_cmp THEN
            RETURN -1;
          ELSE
            RETURN 0;
        END CASE;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.eq(a, b)` that backs the `=` operator.
  """
  @spec create_func_eq() :: :ok
  def create_func_eq do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:eq, Migration.repo()),
        args: [a: :rational, b: :rational],
        returns: :boolean,
        body: """
        RETURN #{private_function(:cmp, Migration.repo())}(a, b) = 0;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.neq(a, b)` that backs the `<>` operator.
  """
  @spec create_func_neq() :: :ok
  def create_func_neq do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:neq, Migration.repo()),
        args: [a: :rational, b: :rational],
        returns: :boolean,
        body: """
        RETURN #{private_function(:cmp, Migration.repo())}(a, b) != 0;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.lt(a, b)` that backs the `<` operator.
  """
  @spec create_func_lt() :: :ok
  def create_func_lt do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:lt, Migration.repo()),
        args: [a: :rational, b: :rational],
        returns: :boolean,
        body: """
        RETURN #{private_function(:cmp, Migration.repo())}(a, b) = -1;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.lte(a, b)` that backs the `<=` operator.
  """
  @spec create_func_lte() :: :ok
  def create_func_lte do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:lte, Migration.repo()),
        args: [a: :rational, b: :rational],
        declares: [
          cmp: {:integer, "#{private_function(:cmp, Migration.repo())}(a, b)"},
          cmp_array: :"integer[]"
        ],
        returns: :boolean,
        body: """
        cmp_array := ARRAY_APPEND(cmp_array, cmp);
        RETURN cmp_array <@ '{-1, 0}';
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.gt(a, b)` that backs the `>` operator.
  """
  @spec create_func_gt() :: :ok
  def create_func_gt do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:gt, Migration.repo()),
        args: [a: :rational, b: :rational],
        returns: :boolean,
        body: """
        RETURN #{private_function(:cmp, Migration.repo())}(a, b) = 1;
        """
      )

    Migration.execute(create_func)
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational_private.gte(a, b)` that backs the `>=` operator.
  """
  @spec create_func_gte() :: :ok
  def create_func_gte do
    create_func =
      Postgres.Utils.create_plpgsql_function(
        private_function(:gte, Migration.repo()),
        args: [a: :rational, b: :rational],
        declares: [
          cmp: {:integer, "#{private_function(:cmp, Migration.repo())}(a, b)"},
          cmp_array: :"integer[]"
        ],
        returns: :boolean,
        body: """
        cmp_array := ARRAY_APPEND(cmp_array, cmp);
        RETURN cmp_array <@ '{1, 0}';
        """
      )

    Migration.execute(create_func)
  end

  ## ARITHMATIC OPS

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `+` operator.
  """
  @spec create_op_add() :: :ok
  def create_op_add do
    create_op =
      Postgres.Utils.create_operator(
        :+,
        :rational,
        :rational,
        private_function(:add, Migration.repo()),
        commutator: :+
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `-` operator.
  """
  @spec create_op_sub() :: :ok
  def create_op_sub do
    create_op =
      Postgres.Utils.create_operator(
        :-,
        :rational,
        :rational,
        private_function(:sub, Migration.repo())
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `*` operator.
  """
  @spec create_op_mult() :: :ok
  def create_op_mult do
    create_op =
      Postgres.Utils.create_operator(
        :*,
        :rational,
        :rational,
        private_function(:mult, Migration.repo()),
        commutator: :*
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `/` operator.
  """
  @spec create_op_div() :: :ok
  def create_op_div do
    create_op =
      Postgres.Utils.create_operator(
        :/,
        :rational,
        :rational,
        private_function(:div, Migration.repo())
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `%` operator.
  """
  @spec create_op_modulo() :: :ok
  def create_op_modulo do
    create_op =
      Postgres.Utils.create_operator(
        :%,
        :rational,
        :rational,
        private_function(:modulo, Migration.repo())
      )

    Migration.execute(create_op)
  end

  ## COMPARISON OPS

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `=` operator.
  """
  @spec create_op_eq() :: :ok
  def create_op_eq do
    create_op =
      Postgres.Utils.create_operator(
        :=,
        :rational,
        :rational,
        private_function(:eq, Migration.repo()),
        commutator: :=,
        negator: :<>
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<>` operator.
  """
  @spec create_op_neq() :: :ok
  def create_op_neq do
    create_op =
      Postgres.Utils.create_operator(
        :<>,
        :rational,
        :rational,
        private_function(:neq, Migration.repo()),
        commutator: :<>,
        negator: :=
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `!=` operator.
  """
  @spec create_op_neq2() :: :ok
  def create_op_neq2 do
    create_op =
      Postgres.Utils.create_operator(
        :!=,
        :rational,
        :rational,
        private_function(:neq, Migration.repo()),
        commutator: :!=,
        negator: :=
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_lt() :: :ok
  def create_op_lt do
    create_op =
      Postgres.Utils.create_operator(
        :<,
        :rational,
        :rational,
        private_function(:lt, Migration.repo()),
        commutator: :>,
        negator: :>=
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_lte() :: :ok
  def create_op_lte do
    create_op =
      Postgres.Utils.create_operator(
        :<=,
        :rational,
        :rational,
        private_function(:lte, Migration.repo()),
        commutator: :>=,
        negator: :>
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_gt() :: :ok
  def create_op_gt do
    create_op =
      Postgres.Utils.create_operator(
        :>,
        :rational,
        :rational,
        private_function(:gt, Migration.repo()),
        commutator: :<,
        negator: :<=
      )

    Migration.execute(create_op)
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_gte() :: :ok
  def create_op_gte do
    create_op =
      Postgres.Utils.create_operator(
        :>=,
        :rational,
        :rational,
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
        :rational_ops_btree,
        :rational,
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

  ## CASTS

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
        private_function(:cast_to_double, Migration.repo())
      )

    Migration.execute(create_cast)
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
    constraint =
      Migration.constraint(
        table,
        "#{field_name}_denominator_positive",
        check: """
        (#{field_name}).denominator > 0
        """
      )

    %Constraint{} = Migration.create(constraint)

    :ok
  end

  @doc """
  Returns the config-qualified name of the function for this type.
  """
  @spec function(atom(), Ecto.Repo.t()) :: String.t()
  def function(name, repo) do
    function_prefix = Postgres.Utils.type_function_prefix(repo, :pg_rational)
    "#{function_prefix}#{name}"
  end

  # Returns the config-qualified name of the function for this type.
  @doc false
  @spec private_function(atom(), Ecto.Repo.t()) :: String.t()
  def private_function(name, repo) do
    function_prefix = Postgres.Utils.type_private_function_prefix(repo, :pg_rational)
    "#{function_prefix}#{name}"
  end
end
