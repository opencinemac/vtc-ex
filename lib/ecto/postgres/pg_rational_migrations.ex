use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgRational.Migrations do
  @moduledoc """
  Migrations for adding rational types, casts, functions and constraints to a
  Postgres database.
  """
  alias Ecto.Migration
  alias Ecto.Migration.Constraint
  alias Vtc.Ecto.Postgres
  alias Vtc.Ecto.Postgres.Fragments

  require Ecto.Migration

  @typedoc """
  Indicates returned string is am SQL command.
  """
  @type raw_sql() :: String.t()

  @doc section: :migrations_full
  @doc """
  Adds raw SQL queries to a migration for creating the database types, associated
  functions, casts, operators, and operator families.

  This migration included all migraitons under the
  [Pg Types](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-types),
  [Pg Operators](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-operators),
  [Pg Operator Classes](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-operator-classes),
  [Pg Functions](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-functions),
  [Pg Private Functions](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-private-functions),
  headings, and
  [Pg Casts](Vtc.Ecto.Postgres.PgRational.Migrations.html#pg-casts)

  Safe to run multiple times when new functionality is added in updates to this library.
  Existing values will be skipped.

  Individual migration functions return raw sql commands in an
  {up_command, down_command} tuple.

  ## Options

  - `include`: A list of migration functions to inclide. If not set, all sub-migrations
    will be included.

  - `exclude`: A list of migration functions to exclude. If not set, no sub-migrations
    will be excluded.

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
      rational: [
        functions_schema: :rational,
        functions_prefix: "rational"
      ]
    ]
  ```

  Option definitions are as follows:

  - `functions_schema`: The postgres schema to store rational-related custom functions.

  - `functions_prefix`: A prefix to add before all functions. Defaults to "rational"
    for any function created in the `:public` schema, and "" otherwise.

  ## Private Functions

  Some custom function names are prefaced with `__private__`. These functions should
  not be called by end-users, as they are not subject to *any* API staility guarantees.

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
  @spec create_all(include: Keyword.t(), exclude: Keyword.t()) :: :ok
  def create_all(opts \\ []) do
    migrations = [
      &create_type/0,
      &create_function_schemas/0,
      &create_func_simplify/0,
      &create_func_minus/0,
      &create_func_abs/0,
      &create_func_round/0,
      &create_func_floor/0,
      &create_func_add/0,
      &create_func_sub/0,
      &create_func_mult/0,
      &create_func_div/0,
      &create_func_floor_div/0,
      &create_func_modulo/0,
      &create_op_add/0,
      &create_op_sub/0,
      &create_op_mult/0,
      &create_op_div/0,
      &create_op_modulo/0,
      &create_func_cmp/0,
      &create_func_eq/0,
      &create_func_neq/0,
      &create_func_lt/0,
      &create_func_lte/0,
      &create_func_gt/0,
      &create_func_gte/0,
      &create_op_eq/0,
      &create_op_neq/0,
      &create_op_lt/0,
      &create_op_lte/0,
      &create_op_gt/0,
      &create_op_gte/0,
      &create_op_class_btree/0,
      &create_func_cast_to_double_precison/0,
      &create_func_cast_bigint_to_rational/0,
      &create_cast_double_precision/0,
      &create_cast_bigint_to_rational/0
    ]

    Postgres.Utils.run_migrations(migrations, opts)
  end

  @doc section: :migrations_types
  @doc """
  Adds:

  - `rational` composite type
  - `rationals` schema
  - `rationals_helpers` schema
  """
  @spec create_type() :: {raw_sql(), raw_sql()}
  def create_type do
    Postgres.Utils.create_type(:rational,
      numerator: :bigint,
      denominator: :bigint
    )
  end

  @doc section: :migrations_types
  @doc """
  Creates function schema as described by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgRational.Migrations.html#create_all/0-configuring-database-objects)
  section above.
  """
  @spec create_function_schemas() :: {raw_sql(), raw_sql()}
  def create_function_schemas, do: Postgres.Utils.create_type_schema(:rational)

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__simplify(rat)` function that simplifies a rational. Used at
  the end of every rational operation to avoid overflows.
  """
  @spec create_func_simplify() :: {raw_sql(), raw_sql()}
  def create_func_simplify do
    Postgres.Utils.create_plpgsql_function(
      private_function(:simplify, Migration.repo()),
      args: [input: :rational],
      returns: :rational,
      declares: [
        greatest_denom: {:bigint, "GCD(input.numerator, input.denominator)"},
        denominator: {:bigint, "ABS(input.denominator / greatest_denom)"},
        numerator: {:bigint, "input.numerator / greatest_denom"}
      ],
      body: """
      numerator := numerator * SIGN((input).denominator);
      RETURN (numerator, denominator);
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `rational.minus(rat)` function that flips the sign of the input value --
  makes a positive value negative and a negative value positive.
  """
  @spec create_func_minus() :: {raw_sql(), raw_sql()}
  def create_func_minus do
    Postgres.Utils.create_plpgsql_function(
      function(:minus, Migration.repo()),
      args: [input: :rational],
      returns: :rational,
      body: """
      RETURN ((input).numerator * -1, (input).denominator)::rational;
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `ABS(rational)` function that returns the absolute value of the rational
  value.
  """
  @spec create_func_abs() :: {raw_sql(), raw_sql()}
  def create_func_abs do
    Postgres.Utils.create_plpgsql_function(
      "ABS",
      args: [input: :rational],
      returns: :rational,
      body: """
      RETURN (ABS((input).numerator), ABS((input).denominator))::rational;
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `ROUND(rational)` function that returns the rational input, rounded to the
  nearest :bigint.
  """
  @spec create_func_round() :: {raw_sql(), raw_sql()}
  def create_func_round do
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
  end

  @doc section: :migrations_functions
  @doc """
  Creates `FLOOR(rational)` function that returns the rational input as a `bigint`,
  rounded towards zero, to match Postgres `FLOOR(real)` behavior.
  """
  @spec create_func_floor() :: {raw_sql(), raw_sql()}
  def create_func_floor do
    Postgres.Utils.create_plpgsql_function(
      "FLOOR",
      args: [input: :rational],
      returns: :bigint,
      body: """
      RETURN ((input).numerator / (input).denominator);
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates a native CAST from `rational` to `double precision`.
  """
  @spec create_func_cast_to_double_precison() :: {raw_sql(), raw_sql()}
  def create_func_cast_to_double_precison do
    Postgres.Utils.create_plpgsql_function(
      private_function(:cast_to_double, Migration.repo()),
      args: [value: :rational],
      returns: :"double precision",
      body: """
      RETURN CAST ((value).numerator AS double precision) / CAST ((value).denominator AS double precision);
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates a native CAST from `bigint` to `rational`.
  """
  @spec create_func_cast_bigint_to_rational() :: {raw_sql(), raw_sql()}
  def create_func_cast_bigint_to_rational do
    Postgres.Utils.create_plpgsql_function(
      private_function(:cast_bigint_to_rational, Migration.repo()),
      args: [value: :bigint],
      returns: :rational,
      body: """
      RETURN (value, 1)::rational;
      """
    )
  end

  ## ARITHMATIC BACKING FUNCS

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__add(a, b)` backing function for the `+` operator
  between two rationals.
  """
  @spec create_func_add() :: {raw_sql(), raw_sql()}
  def create_func_add do
    Postgres.Utils.create_plpgsql_function(
      private_function(:add, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: [
        numerator: {:bigint, "((a).numerator * (b).denominator) + ((b).numerator * (a).denominator)"},
        denominator: {:bigint, "(a).denominator * (b).denominator"},
        greatest_denom: {:bigint, "GCD(numerator, denominator)"}
      ],
      returns: :rational,
      body: """
      #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

      RETURN (numerator, denominator);
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__sub(a, b)` backing function for the `-` operator
  between two rationals.
  """
  @spec create_func_sub() :: {raw_sql(), raw_sql()}
  def create_func_sub do
    Postgres.Utils.create_plpgsql_function(
      private_function(:sub, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: [
        numerator: {:bigint, "((a).numerator * (b).denominator) - ((b).numerator * (a).denominator)"},
        denominator: {:bigint, "(a).denominator * (b).denominator"},
        greatest_denom: {:bigint, "GCD(numerator, denominator)"}
      ],
      returns: :rational,
      body: """
      #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

      RETURN (numerator, denominator);
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__mult(a, b)` backing function for the `*` operator
  between two rationals.
  """
  @spec create_func_mult() :: {raw_sql(), raw_sql()}
  def create_func_mult do
    Postgres.Utils.create_plpgsql_function(
      private_function(:mult, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: [
        numerator: {:bigint, "(a).numerator * (b).numerator"},
        denominator: {:bigint, "(a).denominator * (b).denominator"},
        greatest_denom: {:bigint, "GCD(numerator, denominator)"}
      ],
      returns: :rational,
      body: """
      #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

      RETURN (numerator, denominator);
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__div(a, b)` backing function for the `/` operator
  between two rationals.
  """
  @spec create_func_div() :: {raw_sql(), raw_sql()}
  def create_func_div do
    Postgres.Utils.create_plpgsql_function(
      private_function(:div, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: [
        numerator: {:bigint, "(a).numerator * (b).denominator"},
        denominator: {:bigint, "(a).denominator * (b).numerator"},
        greatest_denom: {:bigint, "GCD(numerator, denominator)"}
      ],
      returns: :rational,
      body: """
      #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

      RETURN (numerator, denominator);
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__div(a, b)` backing function for the `/` operator
  between two rationals.
  """
  @spec create_func_floor_div() :: {raw_sql(), raw_sql()}
  def create_func_floor_div do
    Postgres.Utils.create_plpgsql_function(
      "DIV",
      args: [a: :rational, b: :rational],
      declares: [
        numerator: {:bigint, "(a).numerator * (b).denominator"},
        denominator: {:bigint, "(a).denominator * (b).numerator"}
      ],
      returns: :bigint,
      body: """
      RETURN numerator / denominator;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__modulo(a, b)` backing function for the `%` operator
  between two rationals.
  """
  @spec create_func_modulo() :: {raw_sql(), raw_sql()}
  def create_func_modulo do
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
        denominator: {:bigint, "(dividend).denominator * (divisor).denominator"},
        greatest_denom: {:bigint, "GCD(numerator, denominator)"}
      ],
      returns: :rational,
      body: """
      #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

      RETURN (numerator, denominator);
      """
    )
  end

  ## COMPARISON BACKING FUNCS

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__cmp(a, b)` that returns:

    - `1` if a > b
    - `0` if a == b
    - `-1` if a < b

  Used to back equality operators.
  """
  @spec create_func_cmp() :: {raw_sql(), raw_sql()}
  def create_func_cmp do
    Postgres.Utils.create_plpgsql_function(
      private_function(:cmp, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: [
        a_cmp: {:bigint, "((a).numerator * (b).denominator)"},
        b_cmp: {:bigint, "((b).numerator * (a).denominator)"}
      ],
      returns: :integer,
      body: """
      RETURN sign(a_cmp - b_cmp);
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__eq(a, b)` that backs the `=` operator.
  """
  @spec create_func_eq() :: {raw_sql(), raw_sql()}
  def create_func_eq do
    Postgres.Utils.create_plpgsql_function(
      private_function(:eq, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = 0;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__neq(a, b)` that backs the `<>` operator.
  """
  @spec create_func_neq() :: {raw_sql(), raw_sql()}
  def create_func_neq do
    Postgres.Utils.create_plpgsql_function(
      private_function(:neq, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign != 0;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__lt(a, b)` that backs the `<` operator.
  """
  @spec create_func_lt() :: {raw_sql(), raw_sql()}
  def create_func_lt do
    Postgres.Utils.create_plpgsql_function(
      private_function(:lt, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = -1;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__lte(a, b)` that backs the `<=` operator.
  """
  @spec create_func_lte() :: {raw_sql(), raw_sql()}
  def create_func_lte do
    Postgres.Utils.create_plpgsql_function(
      private_function(:lte, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = -1 or cmp_sign = 0;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__gt(a, b)` that backs the `>` operator.
  """
  @spec create_func_gt() :: {raw_sql(), raw_sql()}
  def create_func_gt do
    Postgres.Utils.create_plpgsql_function(
      private_function(:gt, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = 1;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__gte(a, b)` that backs the `>=` operator.
  """
  @spec create_func_gte() :: {raw_sql(), raw_sql()}
  def create_func_gte do
    Postgres.Utils.create_plpgsql_function(
      private_function(:gte, Migration.repo()),
      args: [a: :rational, b: :rational],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = 1 or cmp_sign = 0;
      """
    )
  end

  ## ARITHMATIC OPS

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `+` operator.
  """
  @spec create_op_add() :: {raw_sql(), raw_sql()}
  def create_op_add do
    Postgres.Utils.create_operator(
      :+,
      :rational,
      :rational,
      private_function(:add, Migration.repo()),
      commutator: :+
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `-` operator.
  """
  @spec create_op_sub() :: {raw_sql(), raw_sql()}
  def create_op_sub do
    Postgres.Utils.create_operator(
      :-,
      :rational,
      :rational,
      private_function(:sub, Migration.repo())
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `*` operator.
  """
  @spec create_op_mult() :: {raw_sql(), raw_sql()}
  def create_op_mult do
    Postgres.Utils.create_operator(
      :*,
      :rational,
      :rational,
      private_function(:mult, Migration.repo()),
      commutator: :*
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `/` operator.
  """
  @spec create_op_div() :: {raw_sql(), raw_sql()}
  def create_op_div do
    Postgres.Utils.create_operator(
      :/,
      :rational,
      :rational,
      private_function(:div, Migration.repo())
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `%` operator.
  """
  @spec create_op_modulo() :: {raw_sql(), raw_sql()}
  def create_op_modulo do
    Postgres.Utils.create_operator(
      :%,
      :rational,
      :rational,
      private_function(:modulo, Migration.repo())
    )
  end

  ## COMPARISON OPS

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `=` operator.
  """
  @spec create_op_eq() :: {raw_sql(), raw_sql()}
  def create_op_eq do
    Postgres.Utils.create_operator(
      :=,
      :rational,
      :rational,
      private_function(:eq, Migration.repo()),
      commutator: :=,
      negator: :<>
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<>` operator.
  """
  @spec create_op_neq() :: {raw_sql(), raw_sql()}
  def create_op_neq do
    Postgres.Utils.create_operator(
      :<>,
      :rational,
      :rational,
      private_function(:neq, Migration.repo()),
      commutator: :<>,
      negator: :=
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_lt() :: {raw_sql(), raw_sql()}
  def create_op_lt do
    Postgres.Utils.create_operator(
      :<,
      :rational,
      :rational,
      private_function(:lt, Migration.repo()),
      commutator: :>,
      negator: :>=
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_lte() :: {raw_sql(), raw_sql()}
  def create_op_lte do
    Postgres.Utils.create_operator(
      :<=,
      :rational,
      :rational,
      private_function(:lte, Migration.repo()),
      commutator: :>=,
      negator: :>
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_gt() :: {raw_sql(), raw_sql()}
  def create_op_gt do
    Postgres.Utils.create_operator(
      :>,
      :rational,
      :rational,
      private_function(:gt, Migration.repo()),
      commutator: :<,
      negator: :<=
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_gte() :: {raw_sql(), raw_sql()}
  def create_op_gte do
    Postgres.Utils.create_operator(
      :>=,
      :rational,
      :rational,
      private_function(:gte, Migration.repo()),
      commutator: :<=,
      negator: :<
    )
  end

  ## OPERATOR CLASSES

  @doc section: :migrations_operator_classes
  @doc """
  Creates a B-tree operator class to support indexing on comparison operations.
  """
  @spec create_op_class_btree() :: {raw_sql(), raw_sql()}
  def create_op_class_btree do
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
  end

  ## CASTS

  @doc section: :migrations_casts
  @doc """
  Creates a native cast for:

  ```sql
  rational AS double precision
  ```
  """
  @spec create_cast_double_precision() :: {raw_sql(), raw_sql()}
  def create_cast_double_precision do
    Postgres.Utils.create_cast(
      :rational,
      :"double precision",
      private_function(:cast_to_double, Migration.repo())
    )
  end

  @doc section: :migrations_casts
  @doc """
  Creates a native cast for:

  ```sql
  bigint AS rational
  ```
  """
  @spec create_cast_bigint_to_rational() :: {raw_sql(), raw_sql()}
  def create_cast_bigint_to_rational do
    Postgres.Utils.create_cast(
      :bigint,
      :rational,
      private_function(:cast_bigint_to_rational, Migration.repo()),
      implicit: true
    )
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
  @spec create_constraints(atom(), atom()) :: :ok
  def create_constraints(table, field_name) do
    sql_field = "#{table}.#{field_name}"

    constraint =
      Migration.constraint(
        table,
        "#{field_name}_denominator_positive",
        check: """
        (#{sql_field}).denominator > 0
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
    function_prefix = Postgres.Utils.type_function_prefix(repo, :rational)
    "#{function_prefix}#{name}"
  end

  # Returns the config-qualified name of the function for this type.
  @doc false
  @spec private_function(atom(), Ecto.Repo.t()) :: String.t()
  def private_function(name, repo) do
    function_prefix = Postgres.Utils.type_private_function_prefix(repo, :rational)
    "#{function_prefix}#{name}"
  end

  # Returns declaration list for comparison operators,
  @spec compare_declarations() :: Postgres.Utils.function_declarations()
  defp compare_declarations do
    [
      a_cmp: {:bigint, "((a).numerator * (b).denominator)"},
      b_cmp: {:bigint, "((b).numerator * (a).denominator)"},
      cmp_sign: {:bigint, "SIGN(a_cmp - b_cmp)"}
    ]
  end
end
