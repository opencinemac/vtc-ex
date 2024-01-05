use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgRational.Migrations do
  @moduledoc """
  Migrations for adding rational types, casts, functions and constraints to a
  Postgres database.
  """
  use Vtc.Ecto.Postgres.PgTypeMigration

  alias Ecto.Migration
  alias Ecto.Migration.Constraint
  alias Vtc.Ecto.Postgres.Fragments
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Ecto.Postgres.PgTypeMigration

  require Ecto.Migration

  @doc section: :migrations_full
  @doc """
  Adds raw SQL queries to a migration for creating the database types, associated
  functions, casts, operators, and operator families.

  This migration includes all migrations under the
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

  - `include`: A list of migration functions to include. If not set, all sub-migrations
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
  Repo configuration:

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

  ## Examples

  ```elixir
  defmodule MyMigration do
    use Ecto.Migration

    alias Vtc.Ecto.Postgres.PgRational
    require PgRational.Migrations

    def change do
      PgRational.Migrations.run()
    end
  end
  ```
  """
  @spec run(include: Keyword.t(atom()), exclude: Keyword.t(atom())) :: :ok
  def run(opts \\ []), do: PgTypeMigration.run_for(__MODULE__, opts)

  @doc false
  @impl PgTypeMigration
  @spec ecto_type() :: module()
  def ecto_type, do: PgRational

  @doc false
  @impl PgTypeMigration
  @spec migrations_list() :: [PgTypeMigration.migration_func()]
  def migrations_list do
    [
      &create_type/0,
      &create_function_schemas/0,
      &create_func_simplify/0,
      &create_func_minus/0,
      &create_func_abs/0,
      &create_func_sign/0,
      &create_func_round/0,
      &create_func_floor/0,
      &create_func_add/0,
      &create_func_sub/0,
      &create_func_mult/0,
      &create_func_div/0,
      &create_func_floor_div/0,
      &create_func_modulo/0,
      &create_op_abs/0,
      &create_op_minus/0,
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
      &create_func_cast_to_double_precision/0,
      &create_func_cast_bigint_to_rational/0,
      &create_cast_double_precision/0,
      &create_cast_bigint_to_rational/0
    ]
  end

  @doc section: :migrations_types
  @doc """
  Adds:

  - `rational` composite type
  - `rationals` schema
  - `rationals_helpers` schema
  """
  @spec create_type() :: migration_info()
  def create_type do
    PgTypeMigration.create_type(:rational,
      numerator: :bigint,
      denominator: :bigint
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__simplify(rat)` function that simplifies a rational. Used at
  the end of every rational operation to avoid overflows.
  """
  @spec create_func_simplify() :: migration_info()
  def create_func_simplify do
    PgTypeMigration.create_plpgsql_function(
      private_function(:simplify),
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
  Creates `rational.__private__minus(rat)` function that flips the sign of the input
  value -- makes a positive value negative and a negative value positive.
  """
  @spec create_func_minus() :: migration_info()
  def create_func_minus do
    PgTypeMigration.create_plpgsql_function(
      private_function(:minus),
      args: [input: :rational],
      returns: :rational,
      body: """
      RETURN ((input).numerator * -1, (input).denominator);
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `ABS(rational)` function that returns the absolute value of the rational
  value.
  """
  @spec create_func_abs() :: migration_info()
  def create_func_abs do
    PgTypeMigration.create_plpgsql_function(
      "ABS",
      args: [input: :rational],
      returns: :rational,
      body: """
      RETURN (ABS((input).numerator), ABS((input).denominator));
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `ABS(rational)` function that returns the absolute value of the rational
  value.
  """
  @spec create_func_sign() :: migration_info()
  def create_func_sign do
    PgTypeMigration.create_plpgsql_function(
      "SIGN",
      args: [input: :rational],
      returns: :integer,
      body: """
      RETURN SIGN((input).numerator * (input).denominator);
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `ROUND(rational)` function that returns the rational input, rounded to the
  nearest :bigint.
  """
  @spec create_func_round() :: migration_info()
  def create_func_round do
    PgTypeMigration.create_plpgsql_function(
      "ROUND",
      args: [input: :rational],
      returns: :bigint,
      body: """
      CASE
        WHEN (input).numerator < 0 THEN
          input := -input;
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
  @spec create_func_floor() :: migration_info()
  def create_func_floor do
    PgTypeMigration.create_plpgsql_function(
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
  @spec create_func_cast_to_double_precision() :: migration_info()
  def create_func_cast_to_double_precision do
    PgTypeMigration.create_plpgsql_function(
      private_function(:cast_to_double),
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
  @spec create_func_cast_bigint_to_rational() :: migration_info()
  def create_func_cast_bigint_to_rational do
    PgTypeMigration.create_plpgsql_function(
      private_function(:cast_bigint_to_rational),
      args: [value: :bigint],
      returns: :rational,
      body: """
      RETURN (value, 1)::rational;
      """
    )
  end

  ## ARITHMETIC BACKING FUNCS

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__add(a, b)` backing function for the `+` operator
  between two rationals.
  """
  @spec create_func_add() :: migration_info()
  def create_func_add do
    PgTypeMigration.create_plpgsql_function(
      private_function(:add),
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
  @spec create_func_sub() :: migration_info()
  def create_func_sub do
    PgTypeMigration.create_plpgsql_function(
      private_function(:sub),
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
  @spec create_func_mult() :: migration_info()
  def create_func_mult do
    PgTypeMigration.create_plpgsql_function(
      private_function(:mult),
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
  @spec create_func_div() :: migration_info()
  def create_func_div do
    PgTypeMigration.create_plpgsql_function(
      private_function(:div),
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
  Creates `DIV(a, b)` function, which executed integer floor division on rational
  values.

  Just like `DIV(real, real)`, `DIV(rational, rational)` floors towards zero.
  """
  @spec create_func_floor_div() :: migration_info()
  def create_func_floor_div do
    PgTypeMigration.create_plpgsql_function(
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
  @spec create_func_modulo() :: migration_info()
  def create_func_modulo do
    PgTypeMigration.create_plpgsql_function(
      private_function(:modulo),
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
  @spec create_func_cmp() :: migration_info()
  def create_func_cmp do
    PgTypeMigration.create_plpgsql_function(
      private_function(:cmp),
      args: [a: :rational, b: :rational],
      declares: [
        a_cmp: {:bigint, "((a).numerator * (b).denominator)"},
        b_cmp: {:bigint, "((b).numerator * (a).denominator)"}
      ],
      returns: :integer,
      body: """
      RETURN SIGN(a_cmp - b_cmp);
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `rational.__private__eq(a, b)` that backs the `=` operator.
  """
  @spec create_func_eq() :: migration_info()
  def create_func_eq do
    PgTypeMigration.create_plpgsql_function(
      private_function(:eq),
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
  @spec create_func_neq() :: migration_info()
  def create_func_neq do
    PgTypeMigration.create_plpgsql_function(
      private_function(:neq),
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
  @spec create_func_lt() :: migration_info()
  def create_func_lt do
    PgTypeMigration.create_plpgsql_function(
      private_function(:lt),
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
  @spec create_func_lte() :: migration_info()
  def create_func_lte do
    PgTypeMigration.create_plpgsql_function(
      private_function(:lte),
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
  @spec create_func_gt() :: migration_info()
  def create_func_gt do
    PgTypeMigration.create_plpgsql_function(
      private_function(:gt),
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
  @spec create_func_gte() :: migration_info()
  def create_func_gte do
    PgTypeMigration.create_plpgsql_function(
      private_function(:gte),
      args: [a: :rational, b: :rational],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = 1 or cmp_sign = 0;
      """
    )
  end

  ## ARITHMETIC OPS

  @doc section: :migrations_operators
  @doc """
  Creates a custom unary :rational `@` unary operator.

  Returns the absolute value of the input.
  """
  @spec create_op_abs() :: migration_info()
  def create_op_abs do
    PgTypeMigration.create_operator(
      :@,
      nil,
      :rational,
      "ABS"
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom unary :rational `-` operator.

  Flips the sign of `value`. Equivalent to `value * -1`.
  """
  @spec create_op_minus() :: migration_info()
  def create_op_minus do
    PgTypeMigration.create_operator(
      :-,
      nil,
      :rational,
      private_function(:minus)
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `+` operator.
  """
  @spec create_op_add() :: migration_info()
  def create_op_add do
    PgTypeMigration.create_operator(
      :+,
      :rational,
      :rational,
      private_function(:add),
      commutator: :+
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `-` operator.
  """
  @spec create_op_sub() :: migration_info()
  def create_op_sub do
    PgTypeMigration.create_operator(
      :-,
      :rational,
      :rational,
      private_function(:sub)
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `*` operator.
  """
  @spec create_op_mult() :: migration_info()
  def create_op_mult do
    PgTypeMigration.create_operator(
      :*,
      :rational,
      :rational,
      private_function(:mult),
      commutator: :*
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `/` operator.
  """
  @spec create_op_div() :: migration_info()
  def create_op_div do
    PgTypeMigration.create_operator(
      :/,
      :rational,
      :rational,
      private_function(:div)
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `%` operator.
  """
  @spec create_op_modulo() :: migration_info()
  def create_op_modulo do
    PgTypeMigration.create_operator(
      :%,
      :rational,
      :rational,
      private_function(:modulo)
    )
  end

  ## COMPARISON OPS

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `=` operator.
  """
  @spec create_op_eq() :: migration_info()
  def create_op_eq do
    PgTypeMigration.create_operator(
      :=,
      :rational,
      :rational,
      private_function(:eq),
      commutator: :=,
      negator: :<>
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<>` operator.
  """
  @spec create_op_neq() :: migration_info()
  def create_op_neq do
    PgTypeMigration.create_operator(
      :<>,
      :rational,
      :rational,
      private_function(:neq),
      commutator: :<>,
      negator: :=
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_lt() :: migration_info()
  def create_op_lt do
    PgTypeMigration.create_operator(
      :<,
      :rational,
      :rational,
      private_function(:lt),
      commutator: :>,
      negator: :>=
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_lte() :: migration_info()
  def create_op_lte do
    PgTypeMigration.create_operator(
      :<=,
      :rational,
      :rational,
      private_function(:lte),
      commutator: :>=,
      negator: :>
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_gt() :: migration_info()
  def create_op_gt do
    PgTypeMigration.create_operator(
      :>,
      :rational,
      :rational,
      private_function(:gt),
      commutator: :<,
      negator: :<=
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :rational, :rational `<` operator.
  """
  @spec create_op_gte() :: migration_info()
  def create_op_gte do
    PgTypeMigration.create_operator(
      :>=,
      :rational,
      :rational,
      private_function(:gte),
      commutator: :<=,
      negator: :<
    )
  end

  ## OPERATOR CLASSES

  @doc section: :migrations_operator_classes
  @doc """
  Creates a B-tree operator class to support indexing on comparison operations.
  """
  @spec create_op_class_btree() :: migration_info()
  def create_op_class_btree do
    PgTypeMigration.create_operator_class(
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
        {private_function(:cmp), 1}
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
  @spec create_cast_double_precision() :: migration_info()
  def create_cast_double_precision do
    PgTypeMigration.create_cast(
      :rational,
      :"double precision",
      private_function(:cast_to_double)
    )
  end

  @doc section: :migrations_casts
  @doc """
  Creates a native cast for:

  ```sql
  bigint AS rational
  ```
  """
  @spec create_cast_bigint_to_rational() :: migration_info()
  def create_cast_bigint_to_rational do
    PgTypeMigration.create_cast(
      :bigint,
      :rational,
      private_function(:cast_bigint_to_rational),
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

  # Returns declaration list for comparison operators.
  @spec compare_declarations() :: PgTypeMigration.function_declarations()
  defp compare_declarations do
    [
      a_cmp: {:bigint, "((a).numerator * (b).denominator)"},
      b_cmp: {:bigint, "((b).numerator * (a).denominator)"},
      cmp_sign: {:bigint, "SIGN(a_cmp - b_cmp)"}
    ]
  end
end
