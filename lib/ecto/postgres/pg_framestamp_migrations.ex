use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramestamp.Migrations do
  @moduledoc """
  Migrations for adding framestamp types, functions and constraints to a
  Postgres database.
  """
  use Vtc.Ecto.Postgres.PgTypeMigration

  alias Ecto.Migration
  alias Vtc.Ecto.Postgres.Fragments
  alias Vtc.Ecto.Postgres.PgFramerate
  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Ecto.Postgres.PgTypeMigration

  require Ecto.Migration

  @typedoc """
  SQL value that can be passed as an atom or a string.
  """
  @type sql_value() :: String.t() | atom()

  @doc section: :migrations_full
  @doc """
  Adds raw SQL queries to a migration for creating the database types, associated
  functions, casts, operators, and operator families.

  This migration includes all migrations under the
  [Pg Types](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#pg-types),
  [Pg Operators](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#pg-operators),
  [Pg Operator Classes](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#pg-operator-classes),
  [Pg Functions](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#pg-functions), and
  [Pg Private Functions](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#pg-private-functions),
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
  CREATE TYPE framestamp AS (
    __seconds_n bigint,
    __seconds_d bigint,
    __rate_n bigint,
    __rate_d bigint,
    __rate_tags framerate_tags[]
  );
  ```

  > #### `Field Access` {: .warning}
  >
  > framestamp's inner fields are considered semi-private to end-users. For working with
  > the seconds / rate values, see `create_func_seconds/0` and `create_func_rate/0`,
  > which create Postgres functions to act as getter functions for working with inner
  > framestamp data.

  ## Schemas Created

  Up to two schemas are created as detailed by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#create_all/0-configuring-database-objects)
  section below.

  ## Configuring Database Objects

  To change where supporting functions are created, add the following to your
  Repo configuration:

  ```elixir
  config :vtc, Vtc.Test.Support.Repo,
    adapter: Ecto.Adapters.Postgres,
    ...
    vtc: [
      framestamp: [
        functions_schema: :framestamp,
        functions_prefix: "framestamp"
      ]
    ]
  ```

  Option definitions are as follows:

  - `functions_schema`: The postgres schema to store framestamp-related custom
     functions.

  - `functions_prefix`: A prefix to add before all functions. Defaults to "framestamp"
    for any function created in the `:public` schema, and "" otherwise.

  ## Private Functions

  Some custom function names are prefaced with `__private__`. These functions should
  not be called by end-users, as they are not subject to *any* API stability guarantees.

  ## Examples

  ```elixir
  defmodule MyMigration do
    use Ecto.Migration

    alias Vtc.Ecto.Postgres.PgFramestamp
    require PgFramestamp.Migrations

    def change do
      PgFramestamp.Migrations.run()
    end
  end
  ```
  """
  @spec run(include: Keyword.t(atom()), exclude: Keyword.t(atom())) :: :ok
  def run(opts \\ []), do: PgTypeMigration.run_for(__MODULE__, opts)

  @doc false
  @impl PgTypeMigration
  def ecto_type, do: PgFramestamp

  @doc false
  @impl PgTypeMigration
  def migrations_list do
    [
      &create_type_framestamp/0,
      &create_function_schemas/0,
      &create_func_simplify/0,
      &create_func_with_seconds/0,
      &create_func_with_frames/0,
      &create_func_seconds/0,
      &create_func_rate/0,
      &create_func_frames/0,
      &create_func_abs/0,
      &create_func_sign/0,
      &create_func_eq/0,
      &create_func_neq/0,
      &create_func_strict_eq/0,
      &create_func_strict_neq/0,
      &create_func_lt/0,
      &create_func_lte/0,
      &create_func_gt/0,
      &create_func_gte/0,
      &create_func_cmp/0,
      &create_func_minus/0,
      &create_func_add/0,
      &create_func_add_inherit_left/0,
      &create_func_add_inherit_right/0,
      &create_func_sub/0,
      &create_func_sub_inherit_left/0,
      &create_func_sub_inherit_right/0,
      &create_func_mult_rational/0,
      &create_func_div_rational/0,
      &create_func_floor_div_rational/0,
      &create_func_modulo_rational/0,
      &create_op_eq/0,
      &create_op_neq/0,
      &create_op_strict_eq/0,
      &create_op_strict_neq/0,
      &create_op_lt/0,
      &create_op_lte/0,
      &create_op_gt/0,
      &create_op_gte/0,
      &create_op_abs/0,
      &create_op_minus/0,
      &create_op_add/0,
      &create_op_add_inherit_left/0,
      &create_op_add_inherit_right/0,
      &create_op_sub/0,
      &create_op_sub_inherit_left/0,
      &create_op_sub_inherit_right/0,
      &create_op_mult_rational/0,
      &create_op_div_rational/0,
      &create_op_modulo_rational/0,
      &create_op_class_btree/0
    ]
  end

  @doc section: :migrations_types
  @doc """
  Adds `framestamp` composite type.

  ## Fields

  - `__seconds_n`: `bigint`. Numerator of the real-world seconds this frame occurred at,
    as a rational value.

  - `__seconds_d`: `bigint`. Denominator of the real-world seconds this frame occurred
    at, as a rational value.

  - `__rate_n`: `bigint`. Numerator of the real-world playback speed of this frame's
    media stream.

  - `__rate_d`: `bigint`. Denominator of the real-world playback speed of this frame's
    media stream.

  - `__rate_tags[]`: Information about the format this framestamp was parsed from, to
    support lossless round-trips.
  """
  @spec create_type_framestamp() :: migration_info()
  def create_type_framestamp do
    PgTypeMigration.create_type(:framestamp,
      __seconds_n: :bigint,
      __seconds_d: :bigint,
      __rate_n: :bigint,
      __rate_d: :bigint,
      __rate_tags: "framerate_tags[]"
    )
  end

  @doc section: :migrations_types
  @doc """
  Creates function schema as described by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#create_all/0-configuring-database-objects)
  section above.
  """
  @spec create_function_schemas() :: migration_info()
  def create_function_schemas, do: PgTypeMigration.create_type_schema(:framestamp)

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__simplify(bigint. bigint)` function that simplifies a
  rational value based on two ints. Used at the end of every rational operation to avoid
  overflows.
  """
  @spec create_func_simplify() :: migration_info()
  def create_func_simplify do
    PgTypeMigration.create_plpgsql_function(
      private_function(:simplify, Migration.repo()),
      args: [numerator_in: :bigint, denominator_in: :bigint],
      returns: :rational,
      declares: [
        greatest_denom: {:bigint, "GCD(numerator_in, denominator_in)"},
        denominator: {:bigint, "ABS(denominator_in / greatest_denom)"},
        numerator: {:bigint, "numerator_in / greatest_denom"}
      ],
      body: """
      numerator := numerator * SIGN(denominator_in);
      RETURN (numerator, denominator);
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framestamp.with_seconds(seconds, rate)`

  Constructs a framestamp for the given real-world `seconds`, rounded to the nearest
  whole-frame based on `rate`. When passed to `framestamp.seconds/1`, the returned value
  will yield the rounded `seconds`.
  """
  @spec create_func_with_seconds() :: migration_info()
  def create_func_with_seconds do
    PgTypeMigration.create_plpgsql_function(
      function(:with_seconds, Migration.repo()),
      args: [seconds: :rational, rate: :framerate],
      returns: :framestamp,
      body: """
      seconds := ROUND((rate).playback * seconds);
      seconds := seconds / (rate).playback;

      RETURN (
        (seconds).numerator,
        (seconds).denominator,
        (rate).playback.numerator,
        (rate).playback.denominator,
        (rate).tags
      );
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framestamp.with_frames(frames, rate)`

  Constructs a framestamp for the given frame count. When passed to
  `framestamp.frames/1`, the returned value will yield `frames`.
  """
  @spec create_func_with_frames() :: migration_info()
  def create_func_with_frames do
    PgTypeMigration.create_plpgsql_function(
      function(:with_frames, Migration.repo()),
      args: [frames: :bigint, rate: :framerate],
      declares: [seconds: {:rational, "frames / (rate).playback"}],
      returns: :framestamp,
      body: """
      RETURN (
        (seconds).numerator,
        (seconds).denominator,
        (rate).playback.numerator,
        (rate).playback.denominator,
        (rate).tags
      );
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Returns the internal real-world `seconds` value as a rational.
  """
  @spec create_func_seconds() :: migration_info()
  def create_func_seconds do
    PgTypeMigration.create_plpgsql_function(
      function(:seconds, Migration.repo()),
      args: [value: :framestamp],
      returns: :rational,
      body: """
      RETURN (value.__seconds_n, value.__seconds_d);
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Returns the internal `framerate` value.
  """
  @spec create_func_rate() :: migration_info()
  def create_func_rate do
    PgTypeMigration.create_plpgsql_function(
      function(:rate, Migration.repo()),
      args: [value: :framestamp],
      returns: :framerate,
      body: """
      RETURN ((value.__rate_n, value.__rate_d), value.__rate_tags)::framerate;
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Converts `framestamp` to a frame number by the frame's index in the timecode
  stream, with `0` as SMPTE midnight.

  Equivalent to [Framestamp.frames/2](`Vtc.Framestamp.frames/2`) with `:round` set to
  `trunc`.
  """
  @spec create_func_frames() :: migration_info()
  def create_func_frames do
    PgTypeMigration.create_plpgsql_function(
      function(:frames, Migration.repo()),
      args: [value: :framestamp],
      declares: [
        frames_rational: {
          :rational,
          """
          ((value).__seconds_n, (value).__seconds_d)::rational
          * ((value).__rate_n, (value).__rate_d)::rational
          """
        }
      ],
      returns: :bigint,
      body: """
      RETURN (frames_rational).numerator / (frames_rational).denominator;
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Returns the absolute value of the framestamp.
  """
  @spec create_func_abs() :: migration_info()
  def create_func_abs do
    PgTypeMigration.create_plpgsql_function(
      "ABS",
      args: [value: :framestamp],
      returns: :framestamp,
      body: """
      RETURN (
        ABS((value).__seconds_n),
        ABS((value).__seconds_d),
        (value).__rate_n,
        (value).__rate_d,
        (value).__rate_tags
      );
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Returns:

    - `-1` if the framestamp's seconds value is less than`0/1`.
    - `0` if the framestamp's seconds value is `0/1`.
    - `1` if the framestamp's seconds value is greater than`0/1`.
  """
  @spec create_func_sign() :: migration_info()
  def create_func_sign do
    PgTypeMigration.create_plpgsql_function(
      "SIGN",
      args: [input: :framestamp],
      returns: :integer,
      body: """
      RETURN SIGN((input).__seconds_n * (input).__seconds_d);
      """
    )
  end

  ## COMPARISON BACKING FUNCTION

  @doc section: :migrations_private_functions
  @doc """
  `framestamp.__private__eq(framestamp, framestamp)`

  Backs the `=` operator.
  """
  @spec create_func_eq() :: migration_info()
  def create_func_eq do
    PgTypeMigration.create_plpgsql_function(
      private_function(:eq, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = 0;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__strict_eq(a, b)` that backs the `===` operator.

  Checks that both the seconds value AND the framerate are equivalent.
  """
  @spec create_func_strict_eq() :: migration_info()
  def create_func_strict_eq do
    PgTypeMigration.create_plpgsql_function(
      private_function(:strict_eq, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = 0
             AND #{sql_check_rate_equal(:a, :b)};
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__neq(a, b)` that backs the `<>` operator.
  """
  @spec create_func_neq() :: migration_info()
  def create_func_neq do
    PgTypeMigration.create_plpgsql_function(
      private_function(:neq, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign != 0;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__strict_neq(a, b)` that backs the `!===` operator.

  Checks if either the seconds value OR the framerate are not equivalent.
  """
  @spec create_func_strict_neq() :: migration_info()
  def create_func_strict_neq do
    PgTypeMigration.create_plpgsql_function(
      private_function(:strict_neq, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign != 0
        OR (a).__rate_n != (b).__rate_n
        OR (a).__rate_d != (b).__rate_d
        OR NOT (a).__rate_tags = (b).__rate_tags;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__lt(a, b)` that backs the `<` operator.
  """
  @spec create_func_lt() :: migration_info()
  def create_func_lt do
    PgTypeMigration.create_plpgsql_function(
      private_function(:lt, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = -1;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__lte(a, b)` that backs the `<=` operator.
  """
  @spec create_func_lte() :: migration_info()
  def create_func_lte do
    PgTypeMigration.create_plpgsql_function(
      private_function(:lte, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = -1 or cmp_sign = 0;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__gt(a, b)` that backs the `>` operator.
  """
  @spec create_func_gt() :: migration_info()
  def create_func_gt do
    PgTypeMigration.create_plpgsql_function(
      private_function(:gt, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = 1;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__gte(a, b)` that backs the `>=` operator.
  """
  @spec create_func_gte() :: migration_info()
  def create_func_gte do
    PgTypeMigration.create_plpgsql_function(
      private_function(:gte, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: compare_declarations(),
      returns: :boolean,
      body: """
      RETURN cmp_sign = 1 or cmp_sign = 0;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__cmp(a, b)` used in the PgTimecode b-tree operator class.
  """
  @spec create_func_cmp() :: migration_info()
  def create_func_cmp do
    PgTypeMigration.create_plpgsql_function(
      private_function(:cmp, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: compare_declarations(),
      returns: :integer,
      body: """
      RETURN SIGN(a_cmp - b_cmp);
      """
    )
  end

  ## ARITHMETIC FUNCTIONS

  @doc section: :migrations_functions
  @doc """
  Creates `framestamp.__private__minus(value)` that backs unary `-` operator.

  Flips the sign of `value`. Equivalent to `value * -1`.
  """
  @spec create_func_minus() :: migration_info()
  def create_func_minus do
    PgTypeMigration.create_plpgsql_function(
      private_function(:minus, Migration.repo()),
      args: [value: :framestamp],
      returns: :framestamp,
      body: """
      RETURN (
        -(value).__seconds_n,
        (value).__seconds_d,
        (value).__rate_n,
        (value).__rate_d,
        (value).__rate_tags
      );
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__add(a, b)` that backs the `+` operator.

  Adds `a` to `b`.

  **raises**: `data_exception` if `a` and `b` do not have the same framerate.
  """
  @spec create_func_add() :: migration_info()
  def create_func_add do
    PgTypeMigration.create_plpgsql_function(
      private_function(:add, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: addition_declares(),
      returns: :framestamp,
      body: """
      IF #{sql_check_rate_equal(:a, :b)} THEN
        #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

        RETURN (
          numerator,
          denominator,
          (a).__rate_n,
          (a).__rate_d,
          (a).__rate_tags
        )::framestamp;
      ELSE
        #{sql_raise_mixed_frame_arithmetic_error(:framestamp, :+)}
      END IF;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__add_inherit_left(a, b)` that backs the `@+` operator.

  Adds `a` to `b`. If `a` and `b` do not have the same framerate, result will inherit
  `a`'s rate and round seconds to the nearest whole-frame.
  """
  @spec create_func_add_inherit_left() :: migration_info()
  def create_func_add_inherit_left do
    with_seconds = function(:with_seconds, Migration.repo())

    PgTypeMigration.create_plpgsql_function(
      private_function(:add_inherit_left, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: addition_declares(),
      returns: :framestamp,
      body: """
      #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

      IF (a).__rate_n = (b).__rate_n
         AND (a).__rate_d = (b).__rate_d
      THEN
        RETURN (
          numerator,
          denominator,
          (a).__rate_n,
          (a).__rate_d,
          (a).__rate_tags
        )::framestamp;
      ELSE
        RETURN #{with_seconds}((numerator, denominator), (((a).__rate_n, (a).__rate_d), (a).__rate_tags));
      END IF;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__add_inherit_right(a, b)` that backs the `+@` operator.

  Adds `a` to `b`. If `a` and `b` do not have the same framerate, result will inherit
  `b`'s rate and round seconds to the nearest whole-frame.
  """
  @spec create_func_add_inherit_right() :: migration_info()
  def create_func_add_inherit_right do
    with_seconds = function(:with_seconds, Migration.repo())

    PgTypeMigration.create_plpgsql_function(
      private_function(:add_inherit_right, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: addition_declares(),
      returns: :framestamp,
      body: """
      #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

      IF (a).__rate_n = (b).__rate_n
         AND (a).__rate_d = (b).__rate_d
      THEN
        RETURN (
          numerator,
          denominator,
          (b).__rate_n,
          (b).__rate_d,
          (b).__rate_tags
        )::framestamp;
      ELSE
        RETURN #{with_seconds}((numerator, denominator), (((b).__rate_n, (b).__rate_d), (b).__rate_tags));
      END IF;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  `framestamp.__private__sub(a, b)` that backs the `-` operator.

  Subtracts `a` from `b`.

  **raises**: `data_exception` if `a` and `b` do not have the same framerate.
  """
  @spec create_func_sub() :: migration_info()
  def create_func_sub do
    PgTypeMigration.create_plpgsql_function(
      private_function(:sub, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: subtraction_declares(),
      returns: :framestamp,
      body: """
      IF #{sql_check_rate_equal(:a, :b)} THEN
        #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

        RETURN (
          numerator,
          denominator,
          (a).__rate_n,
          (a).__rate_d,
          (a).__rate_tags
        )::framestamp;
      ELSE
        #{sql_raise_mixed_frame_arithmetic_error(:framestamp, :-)}
      END IF;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__sub_inherit_left(a, b)` that backs the `@-` operator.

  Subtracts `a` from `b`. If `a` and `b` do not have the same framerate, result will
  inherit `a`'s rate and round seconds to the nearest whole-frame.
  """
  @spec create_func_sub_inherit_left() :: migration_info()
  def create_func_sub_inherit_left do
    with_seconds = function(:with_seconds, Migration.repo())

    PgTypeMigration.create_plpgsql_function(
      private_function(:sub_inherit_left, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: subtraction_declares(),
      returns: :framestamp,
      body: """
      #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

      IF (a).__rate_n = (b).__rate_n
         AND (a).__rate_d = (b).__rate_d
      THEN
        RETURN (
          numerator,
          denominator,
          (a).__rate_n,
          (a).__rate_d,
          (a).__rate_tags
        )::framestamp;
      ELSE
        RETURN #{with_seconds}((numerator, denominator), (((a).__rate_n, (a).__rate_d), (a).__rate_tags));
      END IF;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__sub_inherit_right(a, b)` that backs the `-@` operator.

  Subtracts `a` from `b`. If `a` and `b` do not have the same framerate, result will
  inherit `b`'s rate and round seconds to the nearest whole-frame.
  """
  @spec create_func_sub_inherit_right() :: migration_info()
  def create_func_sub_inherit_right do
    with_seconds = function(:with_seconds, Migration.repo())

    PgTypeMigration.create_plpgsql_function(
      private_function(:sub_inherit_right, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: subtraction_declares(),
      returns: :framestamp,
      body: """
      #{Fragments.sql_inline_simplify(:numerator, :denominator, :greatest_denom)}

      IF (a).__rate_n = (b).__rate_n
         AND (a).__rate_d = (b).__rate_d
      THEN
        RETURN (
          numerator,
          denominator,
          (b).__rate_n,
          (b).__rate_d,
          (b).__rate_tags
        )::framestamp;
      ELSE
        RETURN #{with_seconds}((numerator, denominator), (((b).__rate_n, (b).__rate_d), (b).__rate_tags));
      END IF;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__mult(:framestamp, :rational)` that backs the `*` operator.

  Just like [Framestamp.mult/3](`Vtc.Framestamp.mult/3`), `a`'s the internal `seconds`
  field will be rounded to the nearest whole-frame to ensure data integrity.
  """
  @spec create_func_mult_rational() :: migration_info()
  def create_func_mult_rational do
    with_seconds = function(:with_seconds, Migration.repo())

    PgTypeMigration.create_plpgsql_function(
      private_function(:mult, Migration.repo()),
      args: [a: :framestamp, b: :rational],
      declares: [
        numerator: {:bigint, "(a).__seconds_n * (b).numerator"},
        denominator: {:bigint, "(a).__seconds_d * (b).denominator"},
        rate: {:framerate, "(((a).__rate_n, (a).__rate_d), (a).__rate_tags)"}
      ],
      returns: :framestamp,
      body: """
      RETURN #{with_seconds}((numerator, denominator), rate);
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__div(:framestamp, :rational)` that backs the `/` operator.

  Just like [Framestamp.div/3](`Vtc.Framestamp.div/3`), `a`'s the internal `seconds`
  field will be rounded to the nearest whole-frame to ensure data integrity.

  Unlike [Framestamp.div/3](`Vtc.Framestamp.div/3`), the result is rounded to the
  *closest* frame, rather than truncating ala integer division.
  """
  @spec create_func_div_rational() :: migration_info()
  def create_func_div_rational do
    with_seconds = function(:with_seconds, Migration.repo())

    PgTypeMigration.create_plpgsql_function(
      private_function(:div, Migration.repo()),
      args: [a: :framestamp, b: :rational],
      declares: [
        numerator: {:bigint, "(a).__seconds_n * (b).denominator"},
        denominator: {:bigint, "(a).__seconds_d * (b).numerator"},
        rate: {:framerate, "(((a).__rate_n, (a).__rate_d), (a).__rate_tags)"}
      ],
      returns: :framestamp,
      body: """
      RETURN #{with_seconds}((numerator, denominator), rate);
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `DIV(:framestamp, :rational)` that returns a floored :framestamp to match
  Postgres' DIV(real, real) behavior.

  Just like [Framestamp.div/3](`Vtc.Framestamp.div/3`), this operation is done on the
  frame count representation of the Framestamp, which is then used as the basis of a new
  framestamp.
  """
  @spec create_func_floor_div_rational() :: migration_info()
  def create_func_floor_div_rational do
    framestamp_frames = function(:frames, Migration.repo())
    simplify = PgRational.Migrations.private_function(:simplify, Migration.repo())

    PgTypeMigration.create_plpgsql_function(
      "DIV",
      args: [a: :framestamp, b: :rational],
      declares: [
        frames: {:bigint, "#{framestamp_frames}(a)"},
        playback: {:rational, "((a).__rate_n, (a).__rate_d)"},
        seconds: :rational
      ],
      returns: :framestamp,
      body: """
      frames := DIV(frames, b);
      seconds := #{simplify}(frames / playback);

      RETURN (
        (seconds).numerator,
        (seconds).denominator,
        (a).__rate_n,
        (a).__rate_d,
        (a).__rate_tags
      );
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__modulo(:framestamp, :rational)` that backs the `%`
  operator.

  Just like [Framestamp.rem/3](`Vtc.Framestamp.rem/3`), this operation is done on the
  frame count representation of the Framestamp, which is then used as the basis of a new
  framestamp.
  """
  @spec create_func_modulo_rational() :: migration_info()
  def create_func_modulo_rational do
    framestamp_frames = function(:frames, Migration.repo())
    simplify = PgRational.Migrations.private_function(:simplify, Migration.repo())

    PgTypeMigration.create_plpgsql_function(
      private_function(:modulo, Migration.repo()),
      args: [a: :framestamp, b: :rational],
      declares: [
        frames: {:bigint, "#{framestamp_frames}(a)"},
        playback: {:rational, "((a).__rate_n, (a).__rate_d)"},
        seconds: :rational
      ],
      returns: :framestamp,
      body: """
      frames := ROUND(frames % b);
      seconds := #{simplify}(frames / playback);

      RETURN (
        (seconds).numerator,
        (seconds).denominator,
        (a).__rate_n,
        (a).__rate_d,
        (a).__rate_tags
      );
      """
    )
  end

  ### COMPARISON OPERATORS

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `=` operator that returns true if the
  real-world seconds values for both framestamps are equal.
  """
  @spec create_op_eq() :: migration_info()
  def create_op_eq do
    PgTypeMigration.create_operator(
      :=,
      :framestamp,
      :framestamp,
      private_function(:eq, Migration.repo()),
      commutator: :=,
      negator: :<>
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `===` operator that returns true if *both*
  the real-world seconds values *and* the framerates for both framestamps are equal.
  """
  @spec create_op_strict_eq() :: migration_info()
  def create_op_strict_eq do
    PgTypeMigration.create_operator(
      :===,
      :framestamp,
      :framestamp,
      private_function(:strict_eq, Migration.repo()),
      commutator: :===,
      negator: :"!==="
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `<>` operator that returns true if the
  real-world seconds values for both framestamps are not equal.
  """
  @spec create_op_neq() :: migration_info()
  def create_op_neq do
    PgTypeMigration.create_operator(
      :<>,
      :framestamp,
      :framestamp,
      private_function(:neq, Migration.repo()),
      commutator: :<>,
      negator: :=
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `!===` operator that returns true if `a` and
  `b` do not have the same real-world-seconds, framerate playback, or framerate tags.
  """
  @spec create_op_strict_neq() :: migration_info()
  def create_op_strict_neq do
    PgTypeMigration.create_operator(
      :"!===",
      :framestamp,
      :framestamp,
      private_function(:strict_neq, Migration.repo()),
      commutator: :"!===",
      negator: :===
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `<` operator.
  """
  @spec create_op_lt() :: migration_info()
  def create_op_lt do
    PgTypeMigration.create_operator(
      :<,
      :framestamp,
      :framestamp,
      private_function(:lt, Migration.repo()),
      commutator: :>,
      negator: :>=
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `<=` operator.
  """
  @spec create_op_lte() :: migration_info()
  def create_op_lte do
    PgTypeMigration.create_operator(
      :<=,
      :framestamp,
      :framestamp,
      private_function(:lte, Migration.repo()),
      commutator: :>=,
      negator: :>
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `>` operator.
  """
  @spec create_op_gt() :: migration_info()
  def create_op_gt do
    PgTypeMigration.create_operator(
      :>,
      :framestamp,
      :framestamp,
      private_function(:gt, Migration.repo()),
      commutator: :<,
      negator: :<=
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `>=` operator.
  """
  @spec create_op_gte() :: migration_info()
  def create_op_gte do
    PgTypeMigration.create_operator(
      :>=,
      :framestamp,
      :framestamp,
      private_function(:gte, Migration.repo()),
      commutator: :<=,
      negator: :<
    )
  end

  ## ARITHMETIC OPERATORS

  @doc section: :migrations_operators
  @doc """
  Creates a custom unary :framestamp `@` operator.

  Returns the absolute value of the framestamp.
  """
  @spec create_op_abs() :: migration_info()
  def create_op_abs do
    PgTypeMigration.create_operator(
      :@,
      nil,
      :framestamp,
      "ABS"
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom unary :framestamp `-` operator.

  Flips the sign of `value`. Equivalent to `value * -1`.
  """
  @spec create_op_minus() :: migration_info()
  def create_op_minus do
    PgTypeMigration.create_operator(
      :-,
      nil,
      :framestamp,
      private_function(:minus, Migration.repo())
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `+` operator.

  Adds `a` to `b`.

  **raises**: `data_exception` if `a` and `b` do not have the same framerate.
  """
  @spec create_op_add() :: migration_info()
  def create_op_add do
    PgTypeMigration.create_operator(
      :+,
      :framestamp,
      :framestamp,
      private_function(:add, Migration.repo()),
      commutator: :+
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `@+` operator.

  Adds `a` to `b`. If `a` and `b` do not have the same framerate, result will inherit
  `a`'s rate and round seconds to the nearest whole-frame.
  """
  @spec create_op_add_inherit_left() :: migration_info()
  def create_op_add_inherit_left do
    PgTypeMigration.create_operator(
      :"@+",
      :framestamp,
      :framestamp,
      private_function(:add_inherit_left, Migration.repo()),
      commutator: :"+@"
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `+@` operator.

  Adds `a` to `b`. If `a` and `b` do not have the same framerate, result will inherit
  `b`'s rate and round seconds to the nearest whole-frame.
  """
  @spec create_op_add_inherit_right() :: migration_info()
  def create_op_add_inherit_right do
    PgTypeMigration.create_operator(
      :"+@",
      :framestamp,
      :framestamp,
      private_function(:add_inherit_right, Migration.repo()),
      commutator: :"@+"
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `-` operator.

  Subtracts `a` from `b`.

  **raises**: `data_exception` if `a` and `b` do not have the same framerate.
  """
  @spec create_op_sub() :: migration_info()
  def create_op_sub do
    PgTypeMigration.create_operator(
      :-,
      :framestamp,
      :framestamp,
      private_function(:sub, Migration.repo())
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `@-` operator.

  Subtracts `a` from `b`. If `a` and `b` do not have the same framerate, result will
  inherit `a`'s rate and round seconds to the nearest whole-frame.
  """
  @spec create_op_sub_inherit_left() :: migration_info()
  def create_op_sub_inherit_left do
    PgTypeMigration.create_operator(
      :"@-",
      :framestamp,
      :framestamp,
      private_function(:sub_inherit_left, Migration.repo())
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `-@` operator.

  Subtracts `a` from `b`. If `a` and `b` do not have the same framerate, result will
  inherit `b`'s rate and round seconds to the nearest whole-frame.
  """
  @spec create_op_sub_inherit_right() :: migration_info()
  def create_op_sub_inherit_right do
    PgTypeMigration.create_operator(
      :"-@",
      :framestamp,
      :framestamp,
      private_function(:sub_inherit_right, Migration.repo())
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :rational `*` operator.

  Just like [Framestamp.mult/3](`Vtc.Framestamp.mult/3`), `a`'s the internal `seconds`
  value will be rounded to the nearest whole-frame to ensure data integrity.
  """
  @spec create_op_mult_rational() :: migration_info()
  def create_op_mult_rational do
    PgTypeMigration.create_operator(
      :*,
      :framestamp,
      :rational,
      private_function(:mult, Migration.repo())
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :rational `/` operator.

  Just like [Framestamp.div/3](`Vtc.Framestamp.div/3`), `a`'s the internal `seconds`
  value will be rounded to the nearest whole-frame to ensure data integrity.

  Unlike [Framestamp.div/3](`Vtc.Framestamp.div/3`), the result is rounded to the
  *closest* frame, rather than truncating ala integer division.
  """
  @spec create_op_div_rational() :: migration_info()
  def create_op_div_rational do
    PgTypeMigration.create_operator(
      :/,
      :framestamp,
      :rational,
      private_function(:div, Migration.repo())
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :rational `%` operator.

  Just like [Framestamp.rem/3](`Vtc.Framestamp.rem/3`), this operation is done on the
  frame count representation of the Framestamp, which is then used as the basis of a new
  framestamp.
  """
  @spec create_op_modulo_rational() :: migration_info()
  def create_op_modulo_rational do
    PgTypeMigration.create_operator(
      :%,
      :framestamp,
      :rational,
      private_function(:modulo, Migration.repo())
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
  end

  @typedoc """
  Option types for `create_constraints/2`.
  """
  @type constraint_opt() ::
          {:create_seconds_divisible_by_rate?, boolean()}
          | {:framerate_opts, PgFramerate.Migrations.constraint_opt()}

  @doc section: :migrations_constraints
  @doc """
  Creates basic constraints for a [PgFramestamp](`Vtc.Ecto.Postgres.PgFramestamp`) /
  [Framestamp](`Vtc.Framestamp`) database field.

  ## Options

  - `create_seconds_divisible_by_rate?`: If true, creates
    `{field_name}_seconds_divisible_by_rate` constraint (see below). Default: `true`.

  - `framerate_opts`: Opts for framerate constraints. See
    [PgFramerate.Migrations.create_constraints/3](`Vtc.Ecto.Postgres.PgFramerate.Migrations.create_constraints/3`)

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
  @spec create_constraints(atom(), atom(), [constraint_opt()]) :: :ok
  def create_constraints(table, field, opts \\ []) do
    table
    |> build_constraint_list(field, opts)
    |> Enum.each(&Migration.create(&1))

    :ok
  end

  # Compiles the constraint structs to be created in the database.
  @doc false
  @spec build_constraint_list(sql_value(), sql_value(), [constraint_opt()]) :: [Migration.Constraint.t()]
  def build_constraint_list(table, field, opts) do
    sql_field = "#{table}.#{field}"

    framerate_opts =
      opts
      |> Keyword.get(:framerate_opts, [])
      |> Keyword.put(:check_value, """
      (
        ((#{sql_field}).__rate_n, (#{sql_field}).__rate_d),
        (#{sql_field}).__rate_tags
      )::framerate
      """)

    framerate_list = PgFramerate.Migrations.build_constraint_list(table, field, framerate_opts)

    if Keyword.get(opts, :create_seconds_divisible_by_rate?, true) do
      seconds_divisible_by_rate =
        Migration.constraint(
          table,
          "#{field}_seconds_divisible_by_rate",
          check: """
          (
            ((#{sql_field}).__seconds_n, (#{sql_field}).__seconds_d)::rational
            * ((#{sql_field}).__rate_n, (#{sql_field}).__rate_d)::rational
          )
          % 1::bigint = 0::bigint
          """
        )

      framerate_list ++ [seconds_divisible_by_rate]
    else
      framerate_list
    end
  end

  ### SQL fragment builders

  # Returns declaration list for comparison operators.
  @spec compare_declarations() :: PgTypeMigration.function_declarations()
  defp compare_declarations do
    [
      a_cmp: {:bigint, "((a).__seconds_n * (b).__seconds_d)"},
      b_cmp: {:bigint, "((b).__seconds_n * (a).__seconds_d)"},
      cmp_sign: {:bigint, "SIGN(a_cmp - b_cmp)"}
    ]
  end

  # Returns subtraction declarations.
  @spec addition_declares() :: PgTypeMigration.function_declarations()
  defp addition_declares do
    [
      numerator: {:bigint, "((a).__seconds_n * (b).__seconds_d) + ((b).__seconds_n * (a).__seconds_d)"},
      denominator: {:bigint, "(a).__seconds_d * (b).__seconds_d"},
      greatest_denom: {:bigint, "GCD(numerator, denominator)"}
    ]
  end

  # Returns subtraction declarations.
  @spec subtraction_declares() :: PgTypeMigration.function_declarations()
  defp subtraction_declares do
    [
      numerator: {:bigint, "((a).__seconds_n * (b).__seconds_d) - ((b).__seconds_n * (a).__seconds_d)"},
      denominator: {:bigint, "(a).__seconds_d * (b).__seconds_d"},
      greatest_denom: {:bigint, "GCD(numerator, denominator)"}
    ]
  end

  # Returns SQL statement to raise mixed framerate arithmetic operator.
  @spec sql_raise_mixed_frame_arithmetic_error(atom(), atom()) :: raw_sql()
  defp sql_raise_mixed_frame_arithmetic_error(type, operator) do
    hint =
      "try using `@#{operator}` or `#{operator}@` instead. alternatively, do calculations" <>
        " in seconds before casting back to #{type} with the appropriate framerate" <>
        " using `with_seconds/2`"

    """
    RAISE 'Mixed framerate arithmetic'
    USING
      ERRCODE = 'data_exception',
      HINT = '#{hint}';
    """
  end

  # Checks if two framestamps' framerates are equal. Currently, a framestamp will never
  # have more than one tag, so we can cheat a little and just check if the arrays are
  # equal. If we ever add additional tags, this check will need to change.
  @spec sql_check_rate_equal(atom(), atom()) :: raw_sql()
  defp sql_check_rate_equal(a_stamp_name, b_stamp_name) do
    Enum.join(
      [
        "(#{a_stamp_name}).__rate_n = (#{b_stamp_name}).__rate_n",
        "(#{a_stamp_name}).__rate_d = (#{b_stamp_name}).__rate_d",
        "(#{a_stamp_name}).__rate_tags = (#{b_stamp_name}).__rate_tags"
      ],
      " AND "
    )
  end
end
