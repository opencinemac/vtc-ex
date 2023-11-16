use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramestamp.FastRange do
  @moduledoc """
  Framestamp_fastrange use floats for faster comparison operations and are defined as
  follows:

  ```sql
  CREATE TYPE framestamp_fastrange AS RANGE (
    subtype = double precision,
    subtype_diff = float8mi
  );
  ```

  Framestamp fastranges can be created in SQL expressions like so:

  ```sql
  SELECT framestamp_fastrange(stamp_1, stamp_2)
  ```

  > #### `Indexing` {: .warning}
  >
  > `framestamp_fastrange` is considerably faster than
  > [framestamp_range](`Vtc.Ecto.Postgres.PgFramestamp.Range`) when building GiST
  > indexes.

  > #### `Loading` {: .error}
  >
  > Since FastRanges do not store framerate, they cannot be re-constituted to a normal
  > framestamp range once cast. Trying to deserialize one using this type will fail.

  ## Fragments

  FastRange values must be explicitly cast from a
  [Framestamp.Range](`Vtc.Framestamp.Range`) using
  [type/2](https://hexdocs.pm/ecto/Ecto.Query.html#module-interpolation-and-casting):

  ```elixir
  stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  stamp_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
  stamp_range = Framestamp.Range.new!(stamp_in, stamp_out)

  query = Query.from(
    f in fragment("SELECT ? as r", type(^stamp_range, Framerate.FastRange)), select: f.r
  )
  ```

  Casting in this way serializes our range in elixir, rather than asking the database
  to do so during a query.

  When creating framestamp_fastrange values in this way, the range will always be
  converted to an EXCLUSIVE out point.

  ## On frame-accuracy

  Vtc's position is that rational values are necessary for frame-accurate timecode
  manipulation, so why does it put forth a float-based range type?

  The main risk of using floats is unpredictable floating-point errors stacking up
  during arithmetic operations so that when you go to compare two values that SHOULD
  be equal, they aren't.

  However, if you do all calculations with rational values -- up to the point where you
  need to compare them -- it is safe to cast to floats for the comparison operation, as
  equal rational values will always cast to the same float value.
  """

  use Ecto.Type

  alias Vtc.Framestamp

  @doc section: :ecto_migrations
  @doc """
  The database type for [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`).

  Can be used in migrations as the fields type.
  """
  @impl Ecto.Type
  @spec type() :: atom()
  def type, do: :framestamp_fastrange

  @typedoc """
  Type of the raw composite value that will be sent to the database.
  """
  @type db_record() :: %Postgrex.Range{
          lower: float(),
          lower_inclusive: boolean(),
          upper: float(),
          upper_inclusive: boolean()
        }

  # Handles casting PgRational fields in `Ecto.Changeset`s.
  @doc false
  @impl Ecto.Type
  @spec cast(Framestamp.Range.t()) :: {:ok, Framestamp.Range.t()} | :error
  def cast(%Framestamp.Range{} = range), do: {:ok, range}
  def cast(_), do: :error

  # Handles converting database records into Ratio structs to be used by the
  # application.
  @doc false
  @impl Ecto.Type
  @spec load(db_record()) :: :error
  def load(_db_record), do: :error

  # Handles converting `Framestamp.Range` structs into database records.
  @doc false
  @impl Ecto.Type
  @spec dump(Framestamp.Range.t()) :: {:ok, db_record()} | :error
  def dump(%Framestamp.Range{} = range) do
    range = Framestamp.Range.with_exclusive_out(range)

    db_record = %Postgrex.Range{
      lower: Ratio.to_float(range.in.seconds),
      lower_inclusive: true,
      upper: Ratio.to_float(range.out.seconds),
      upper_inclusive: false
    }

    {:ok, db_record}
  end

  def dump(_), do: :error
end
