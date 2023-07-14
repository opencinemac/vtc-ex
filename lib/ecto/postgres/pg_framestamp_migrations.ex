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

  @typedoc """
  Indicates returned string is am SQL command.
  """
  @type raw_sql() :: String.t()

  @typedoc """
  SQL value that can be passed as an atom or a string.
  """
  @type sql_value() :: String.t() | atom()

  @doc section: :migrations_full
  @doc """
  Adds raw SQL queries to a migration for creating the database types, associated
  functions, casts, operators, and operator families.

  This migration included all migraitons under the
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

  - `include`: A list of migration functions to inclide. If not set, all sub-migrations
    will be included.

  - `exclude`: A list of migration functions to exclude. If not set, no sub-migrations
    will be excluded.

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
  not be called by end-users, as they are not subject to *any* API staility guarantees.

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
  @spec create_all(include: Keyword.t(), exclude: Keyword.t()) :: :ok
  def create_all(opts \\ []) do
    migrations = [
      &create_type_framestamp/0,
      &create_function_schemas/0,
      &create_func_with_seconds/0,
      &create_func_with_frames/0,
      &create_func_frames/0,
      &create_func_eq/0,
      &create_func_neq/0,
      &create_func_strict_eq/0,
      &create_func_strict_neq/0,
      &create_func_lt/0,
      &create_func_lte/0,
      &create_func_gt/0,
      &create_func_gte/0,
      &create_func_cmp/0,
      &create_func_add/0,
      &create_func_sub/0,
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
      &create_op_add/0,
      &create_op_sub/0,
      &create_op_mult_rational/0,
      &create_op_div_rational/0,
      &create_op_modulo_rational/0,
      &create_op_class_btree/0
    ]

    Postgres.Utils.run_migrations(migrations, opts)
  end

  @doc section: :migrations_types
  @doc """
  Adds `framestamp` composite type.
  """
  @spec create_type_framestamp() :: {raw_sql(), raw_sql()}
  def create_type_framestamp do
    Postgres.Utils.create_type(:framestamp,
      seconds: :rational,
      rate: :framerate
    )
  end

  @doc section: :migrations_types
  @doc """
  Creates function schema as described by the
  [Configuring Database Objects](Vtc.Ecto.Postgres.PgFramestamp.Migrations.html#create_all/0-configuring-database-objects)
  section above.
  """
  @spec create_function_schemas() :: {raw_sql(), raw_sql()}
  def create_function_schemas, do: Postgres.Utils.create_type_schema(:framestamp)

  @doc section: :migrations_functions
  @doc """
  `framestamp.with_seconds(seconds, rate)`

  Rounds `seconds` to the nearest whole frame based on `rate` and returns a constructed
  `framestamp`.
  """
  @spec create_func_with_seconds() :: {raw_sql(), raw_sql()}
  def create_func_with_seconds do
    Postgres.Utils.create_plpgsql_function(
      function(:with_seconds, Migration.repo()),
      args: [seconds: :rational, rate: :framerate],
      declares: [rounded: :bigint],
      returns: :framestamp,
      body: """
      rounded := ROUND((rate).playback * seconds);
      RETURN (((rounded, 1)::rational / (rate).playback), rate);
      """
    )
  end

  @doc section: :migrations_functions
  @doc """
  Creates `framestamp.with_frames(frames, rate)` that creates a framestamp for the
  given frame count.
  """
  @spec create_func_with_frames() :: {raw_sql(), raw_sql()}
  def create_func_with_frames do
    Postgres.Utils.create_plpgsql_function(
      function(:with_frames, Migration.repo()),
      args: [frames: :bigint, rate: :framerate],
      declares: [seconds: {:rational, "(frames, 1)::rational / (rate).playback"}],
      returns: :framestamp,
      body: """
      RETURN (seconds, rate);
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
  @spec create_func_frames() :: {raw_sql(), raw_sql()}
  def create_func_frames do
    Postgres.Utils.create_plpgsql_function(
      function(:frames, Migration.repo()),
      args: [value: :framestamp],
      declares: [frames_rational: {:rational, "(value).seconds * (value).rate.playback"}],
      returns: :bigint,
      body: """
      RETURN FLOOR(frames_rational);
      """
    )
  end

  ## COMPARISON BACKING FUNCTION

  @doc section: :migrations_private_functions
  @doc """
  `framestamp.__private__eq(framestamp, framestamp)`

  Backs the `=` operator.
  """
  @spec create_func_eq() :: {raw_sql(), raw_sql()}
  def create_func_eq do
    Postgres.Utils.create_plpgsql_function(
      private_function(:eq, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      returns: :boolean,
      body: """
      RETURN (a).seconds = (b).seconds;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__strict_eq(a, b)` that backs the `===` operator.
  """
  @spec create_func_strict_eq() :: {raw_sql(), raw_sql()}
  def create_func_strict_eq do
    Postgres.Utils.create_plpgsql_function(
      private_function(:strict_eq, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      returns: :boolean,
      body: """
      RETURN (a).seconds = (b).seconds
        AND (a).rate === (b).rate;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__neq(a, b)` that backs the `<>` operator.
  """
  @spec create_func_neq() :: {raw_sql(), raw_sql()}
  def create_func_neq do
    Postgres.Utils.create_plpgsql_function(
      private_function(:neq, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      returns: :boolean,
      body: """
      RETURN (a).seconds <> (b).seconds;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__strict_neq(a, b)` that backs the `!===` operator.
  """
  @spec create_func_strict_neq() :: {raw_sql(), raw_sql()}
  def create_func_strict_neq do
    Postgres.Utils.create_plpgsql_function(
      private_function(:strict_neq, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      returns: :boolean,
      body: """
      RETURN (a).seconds <> (b.seconds)
        OR (a).rate !=== (b).rate;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__lt(a, b)` that backs the `<` operator.
  """
  @spec create_func_lt() :: {raw_sql(), raw_sql()}
  def create_func_lt do
    Postgres.Utils.create_plpgsql_function(
      private_function(:lt, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      returns: :boolean,
      body: """
      RETURN (a).seconds < (b).seconds;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__lte(a, b)` that backs the `<=` operator.
  """
  @spec create_func_lte() :: {raw_sql(), raw_sql()}
  def create_func_lte do
    Postgres.Utils.create_plpgsql_function(
      private_function(:lte, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      returns: :boolean,
      body: """
      RETURN (a).seconds <= (b).seconds;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__gt(a, b)` that backs the `>` operator.
  """
  @spec create_func_gt() :: {raw_sql(), raw_sql()}
  def create_func_gt do
    Postgres.Utils.create_plpgsql_function(
      private_function(:gt, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      returns: :boolean,
      body: """
      RETURN (a).seconds > (b).seconds;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__gte(a, b)` that backs the `>=` operator.
  """
  @spec create_func_gte() :: {raw_sql(), raw_sql()}
  def create_func_gte do
    Postgres.Utils.create_plpgsql_function(
      private_function(:gte, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      returns: :boolean,
      body: """
      RETURN (a).seconds >= (b).seconds;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__cmp(a, b)` used in the PgTimecode b-tree operator class.
  """
  @spec create_func_cmp() :: {raw_sql(), raw_sql()}
  def create_func_cmp do
    rational_cmp = PgRational.Migrations.private_function(:cmp, Migration.repo())

    Postgres.Utils.create_plpgsql_function(
      private_function(:cmp, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      returns: :integer,
      body: """
      RETURN #{rational_cmp}((a).seconds, (b).seconds);
      """
    )
  end

  ## ARITHMETIC FUNCTIONS

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__add(a, b)` that backs the `+` operator.

  Just like [Framestamp.add/3](`Vtc.Framestamp.add/3`), if the `rate` of `a` and `b`
  are not equal, the result will inheret `a`'s framerate, and the internal `seconds`
  field will be rounded to the nearest whole-frame to ensure data integrity.
  """
  @spec create_func_add() :: {raw_sql(), raw_sql()}
  def create_func_add do
    with_seconds = function(:with_seconds, Migration.repo())

    Postgres.Utils.create_plpgsql_function(
      private_function(:add, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: [seconds: {:rational, "(a).seconds + (b).seconds"}],
      returns: :framestamp,
      body: """
      IF (a).rate === (b).rate THEN
        RETURN (seconds, (a).rate)::framestamp;
      ELSE
        RETURN #{with_seconds}(seconds, (a).rate);
      END IF;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  `framestamp.__private__sub(a, b)`.

  Backs the `-` operator.

  Just like [Framestamp.sub/3](`Vtc.Framestamp.sub/3`), if the `rate` of `a` and `b`
  are not equal, the result will inheret `a`'s framerate, and the internal `seconds`
  field will be rounded to the nearest whole-frame to ensure data integrity.
  """
  @spec create_func_sub() :: {raw_sql(), raw_sql()}
  def create_func_sub do
    with_seconds = function(:with_seconds, Migration.repo())

    Postgres.Utils.create_plpgsql_function(
      private_function(:sub, Migration.repo()),
      args: [a: :framestamp, b: :framestamp],
      declares: [seconds: {:rational, "(a).seconds - (b).seconds"}],
      returns: :framestamp,
      body: """
      IF (a).rate === (b).rate THEN
        RETURN (seconds, (a).rate)::framestamp;
      ELSE
        RETURN #{with_seconds}(seconds, (a).rate);
      END IF;
      """
    )
  end

  @doc section: :migrations_private_functions
  @doc """
  Creates `framestamp.__private__mult(:framestamp, :rational)` that backs the `*` operator.

  Just like [Framestamp.add/3](`Vtc.Framestamp.mult/3`), `a`'s the internal `seconds`
  field will be rounded to the nearest whole-frame to ensure data integrity.
  """
  @spec create_func_mult_rational() :: {raw_sql(), raw_sql()}
  def create_func_mult_rational do
    with_seconds = function(:with_seconds, Migration.repo())

    Postgres.Utils.create_plpgsql_function(
      private_function(:mult, Migration.repo()),
      args: [a: :framestamp, b: :rational],
      declares: [seconds: {:rational, "(a).seconds * (b)"}],
      returns: :framestamp,
      body: """
      RETURN #{with_seconds}(seconds, (a).rate);
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
  @spec create_func_div_rational() :: {raw_sql(), raw_sql()}
  def create_func_div_rational do
    with_seconds = function(:with_seconds, Migration.repo())

    Postgres.Utils.create_plpgsql_function(
      private_function(:div, Migration.repo()),
      args: [a: :framestamp, b: :rational],
      declares: [seconds: {:rational, "(a).seconds / (b)"}],
      returns: :framestamp,
      body: """
      RETURN #{with_seconds}(seconds, (a).rate);
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
  @spec create_func_floor_div_rational() :: {raw_sql(), raw_sql()}
  def create_func_floor_div_rational do
    framestamp_frames = function(:frames, Migration.repo())
    simplify = PgRational.Migrations.private_function(:simplify, Migration.repo())

    Postgres.Utils.create_plpgsql_function(
      "DIV",
      args: [a: :framestamp, b: :rational],
      declares: [
        frames: {:bigint, "#{framestamp_frames}(a)"},
        seconds: :rational
      ],
      returns: :framestamp,
      body: """
      frames := DIV(frames, b);
      seconds := #{simplify}(frames / (a).rate.playback);
      RETURN (seconds, (a).rate);
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
  @spec create_func_modulo_rational() :: {raw_sql(), raw_sql()}
  def create_func_modulo_rational do
    framestamp_frames = function(:frames, Migration.repo())
    simplify = PgRational.Migrations.private_function(:simplify, Migration.repo())

    Postgres.Utils.create_plpgsql_function(
      private_function(:modulo, Migration.repo()),
      args: [a: :framestamp, b: :rational],
      declares: [
        frames: {:bigint, "#{framestamp_frames}(a)"},
        seconds: :rational
      ],
      returns: :framestamp,
      body: """
      frames := ROUND(frames % b);
      seconds := #{simplify}(frames / (a).rate.playback);
      RETURN (seconds, (a).rate)::framestamp;
      """
    )
  end

  ### COMPARISON OPERATORS

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `=` operator that returns true if the
  real-world seconds values for both framestamps are equal.
  """
  @spec create_op_eq() :: {raw_sql(), raw_sql()}
  def create_op_eq do
    Postgres.Utils.create_operator(
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
  @spec create_op_strict_eq() :: {raw_sql(), raw_sql()}
  def create_op_strict_eq do
    Postgres.Utils.create_operator(
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
  @spec create_op_neq() :: {raw_sql(), raw_sql()}
  def create_op_neq do
    Postgres.Utils.create_operator(
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
  @spec create_op_strict_neq() :: {raw_sql(), raw_sql()}
  def create_op_strict_neq do
    Postgres.Utils.create_operator(
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
  @spec create_op_lt() :: {raw_sql(), raw_sql()}
  def create_op_lt do
    Postgres.Utils.create_operator(
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
  @spec create_op_lte() :: {raw_sql(), raw_sql()}
  def create_op_lte do
    Postgres.Utils.create_operator(
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
  @spec create_op_gt() :: {raw_sql(), raw_sql()}
  def create_op_gt do
    Postgres.Utils.create_operator(
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
  @spec create_op_gte() :: {raw_sql(), raw_sql()}
  def create_op_gte do
    Postgres.Utils.create_operator(
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
  Creates a custom :framestamp, :framestamp `+` operator.

  Just like [Framestamp.add/3](`Vtc.Framestamp.add/3`), if the `rate` of `a` and `b`
  are not equal, the result will inheret `a`'s framerate, and the internal `seconds`
  field will be rounded to the nearest whole-frame to ensure data integrity.
  """
  @spec create_op_add() :: {raw_sql(), raw_sql()}
  def create_op_add do
    Postgres.Utils.create_operator(
      :+,
      :framestamp,
      :framestamp,
      private_function(:add, Migration.repo())
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :framestamp `-` operator.

  Just like [Framestamp.add/3](`Vtc.Framestamp.sub/3`), if the `rate` of `a` and `b`
  are not equal, the result will inheret `a`'s framerate, and the internal `seconds`
  field will be rounded to the nearest whole-frame to ensure data integrity.
  """
  @spec create_op_sub() :: {raw_sql(), raw_sql()}
  def create_op_sub do
    Postgres.Utils.create_operator(
      :-,
      :framestamp,
      :framestamp,
      private_function(:sub, Migration.repo())
    )
  end

  @doc section: :migrations_operators
  @doc """
  Creates a custom :framestamp, :rational `*` operator.

  Just like [Framestamp.add/3](`Vtc.Framestamp.mult/3`), `a`'s the internal `seconds`
  field will be rounded to the nearest whole-frame to ensure data integrity.
  """
  @spec create_op_mult_rational() :: {raw_sql(), raw_sql()}
  def create_op_mult_rational do
    Postgres.Utils.create_operator(
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
  field will be rounded to the nearest whole-frame to ensure data integrity.

  Unlike [Framestamp.div/3](`Vtc.Framestamp.div/3`), the result is rounded to the
  *closest* frame, rather than truncating ala integer division.
  """
  @spec create_op_div_rational() :: {raw_sql(), raw_sql()}
  def create_op_div_rational do
    Postgres.Utils.create_operator(
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
  @spec create_op_modulo_rational() :: {raw_sql(), raw_sql()}
  def create_op_modulo_rational do
    Postgres.Utils.create_operator(
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
  @spec create_op_class_btree() :: {raw_sql(), raw_sql()}
  def create_op_class_btree do
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
      |> Keyword.put(:check_value, "(#{sql_field}).rate")

    framerate_list = PgFramerate.Migrations.build_constraint_list(table, field, framerate_opts)

    if Keyword.get(opts, :create_seconds_divisible_by_rate?, true) do
      seconds_divisible_by_rate =
        Migration.constraint(
          table,
          "#{field}_seconds_divisible_by_rate",
          check: """
          ((#{sql_field}).seconds * (#{sql_field}).rate.playback) % 1::bigint = 0::bigint
          """
        )

      framerate_list ++ [seconds_divisible_by_rate]
    else
      framerate_list
    end
  end

  @doc """
  Returns the config-qualified name of the function for this type.
  """
  @spec function(atom(), Ecto.Repo.t()) :: String.t()
  def function(name, repo) do
    function_prefix = Postgres.Utils.type_function_prefix(repo, :framestamp)
    "#{function_prefix}#{name}"
  end

  @spec private_function(atom(), Ecto.Repo.t()) :: String.t()
  defp private_function(name, repo) do
    function_prefix = Postgres.Utils.type_private_function_prefix(repo, :framestamp)
    "#{function_prefix}#{name}"
  end
end
