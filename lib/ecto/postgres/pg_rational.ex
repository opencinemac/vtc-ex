use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgRational do
  @moduledoc """
  Defines a composite type for storing rational values as dual int64s. These values
  are cast to `%Ratio{}` structs for use in application code, provided by the `Ratio`
  library.

  The composite type is defined as follows:

  ```sql
  CREATE TYPE rational as (
    numerator bigint,
    denominator bigint
  )
  ```

  Rational values can be cast in SQL expressions like so:

  ```sql
  SELECT (1, 2)::rational
  ```

  See `Vtc.Ecto.Postgres.PgRational.Migrations` for more information on how to create
  `rational` and it's supporting functions in your database.

  ## Field migrations

  You can create a field as a rational during a migration like so:

  ```elixir
  create table("rationals") do
    add(:a, PgRational.type())
    add(:b, PgRational.type())
  end
  ```

  ## Schema fields

  Then in your schema module:

  ```elixir
  defmodule MyApp.Rationals do
  @moduledoc false
  use Ecto.Schema

  alias Vtc.Ecto.Postgres.PgRational

  @type t() :: %__MODULE__{
          a: Ratio.t(),
          b: Ratio.t()
        }

  schema "rationals_01" do
    field(:a, PgRational)
    field(:b, PgRational)
  end
  ```

  ... notice that the schema field type is `PgRational`, but the type-spec field uses
  `Ratio.t()`, the type that our DB fields will be deserialized into.

  ## Changesets

  With the above setup, changesets should just work:

  ```elixir
  def changeset(schema, attrs) do
    schema
    |> Changeset.cast(attrs, [:a, :b])
    |> Changeset.validate_required([:a, :b])
  end
  ```

  Rational values can be cast from the following values in changesets:

  - `%Ratio{}` structs.

  - `[numerator, denominator]` integer arrays. Useful for non-text JSON values that can
    be set in a single field.

  - Strings formatted as `'numerator/denominator'`. Useful for casting from a JSON
    string.
  """

  use Ecto.Type

  @doc section: :ecto_migrations
  @doc """
  The database type for `PgRational`.

  Can be used in migrations as the fields type.
  """
  @impl Ecto.Type
  def type, do: :rational

  @typedoc """
  Type of the raw composite value that will be sent to / received from the database.
  """
  @type db_record() :: {non_neg_integer(), pos_integer()}

  # Handles casting PgRational fields in `Ecto.Changeset`s.
  @doc false
  @impl Ecto.Type
  @spec cast(Ratio.t() | String.t() | [non_neg_integer()]) :: {:ok, Ratio.t()} | :error
  def cast(%Ratio{} = ratio), do: {:ok, ratio}
  def cast([num, denom]) when is_integer(num) and is_integer(denom), do: {:ok, Ratio.new(num, denom)}

  def cast(fraction) when is_binary(fraction) do
    with [num_str, denom_str] <- String.split(fraction, "/"),
         {num, ""} <- Integer.parse(num_str),
         {denom, ""} <- Integer.parse(denom_str) do
      {:ok, Ratio.new(num, denom)}
    else
      _ -> :error
    end
  end

  def cast(_), do: :error

  # Handles converting database records into Ratio structs to be used by the
  # application.
  @doc false
  @impl Ecto.Type
  @spec load(db_record()) :: {:ok, Ratio.t()} | :error
  def load({num, denom}) when is_integer(num) and is_integer(denom), do: {:ok, Ratio.new(num, denom)}
  def load(_), do: :error

  # Handles converting Ratio structs into database records.
  @doc false
  @impl Ecto.Type
  @spec dump(Ratio.t()) :: {:ok, db_record()} | :error
  def dump(%Ratio{} = rational), do: {:ok, {rational.numerator, rational.denominator}}
  def dump(_), do: :error

  @doc section: :ecto_queries
  @doc """
  Serialize `Ratio` for use in a query fragment.

  The fragment must explicitly cast the value to a `::rational` type.

  ## Examples

  ```elixir
  alias Ecto.Query
  require Ecto.Query

  rational = Ratio.new(1, 2)
  rational_sql = PgRational.dump!(rational)

  Query.from(f in fragment("SELECT ?::rational as r", ^rational_sql), select: f.r)
  ```
  """
  @spec dump!(Ratio.t()) :: db_record()
  def dump!(rational) do
    {:ok, db_record} = dump(rational)
    db_record
  end
end
