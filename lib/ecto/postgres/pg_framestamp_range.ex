use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramestamp.Range do
  @moduledoc """
  Defines a custom Range type for dealing with Framestamp ranges.

  The new range types are defined as follows:

  ```sql
  CREATE TYPE framestamp_range AS RANGE (
    subtype = framestamp,
    subtype_diff = framestamp_range_private.subtype_diff
    canonical = framestamp_range_private.canonicalization
  );
  ```

  Framestamp ranges can be created in SQL expressions like so:

  ```sql
  SELECT framestamp_range(stamp_1, stamp_2, '[)')
  ```

  Framestamp fastranges can be created in SQL expressions like so:

  ```sql
  SELECT framestamp_fastrange(stamp_1, stamp_2)
  ```

  > #### `Indexing` {: .warning}
  >
  > `framestamp_range` is currently VERY slow when using a GiST index, consider using
  > a [framestamp_fastrange](Vtc.Ecto.Postgres.PgFramestamp.Range.html#module-framestamp-fast-range)
  > instead.

  ## Canonicalization

  Postgres `framestamp_range` values are ALWAYS coerced to *exclusive out* ranges. That
  means that even if a [Framestamp.Range](`Vtc.Framestamp.Range`) has `:out_type` set to
  `:inclusive` when it is sent to the database, it will come back from the database
  with `:out_type` set to `:exclusive`, and the `:out` field will be adjusted
  accordingly.

  Further, when a Range operation, like a union, would result in an in and out point
  with different framerates, the higher rate will always be selected.

  This unlike the application behavior of `Vtc.Framestamp.Range`, which always inherets
  the rate of the value that apears on the left side. This behavior may be updated to
  match Vtc's application behavior in the future.

  ## Framestamp Fast Range

  In addition to `framestamp_range`, a `framestamp_fastrange` type is defined as well:

  ```sql
  CREATE TYPE framestamp_fastrange AS RANGE (
    subtype = double precision,
    subtype_diff = float8mi
  );
  ```

  Fast ranges are meant to support GiST indexing, as in most cases, `framestamp_range`
  will be VERY slow to index.

  > #### `Frame-accurate` {: .warning}
  >
  > Unlike `framestamp_range`, `framestamp_fastrange` is NOT frame-accurate and should
  > not be used where frame-accuracy is desired or required.

  ## Field migrations

  You can create `framestamp_range` fields during a migration like so:

  ```elixir
  alias Vtc.Framerate

  create table("framestamp_ranges") do
    add(:a, Framestamp.Range.type())
    add(:b, Framestamp.Range.type())
  end
  ```

  [Framestamp.Range](`Vtc.Framestamp.Range`) re-exports the `Ecto.Type` implementation
  of this module, and can be used any place this module would be used.

  ## Schema fields

  Then in your schema module:

  ```elixir
  defmodule MyApp.FramestampRanges do
  @moduledoc false
  use Ecto.Schema

  alias Vtc.Framestamp

  @type t() :: %__MODULE__{
          a: Framestamp.Range.t(),
          b: Framestamp.Range.t()
        }

  schema "rationals_01" do
    field(:a, Framestamp.Range)
    field(:b, Framestamp.Range)
  end
  ```

  ## Changesets

  With the above setup, changesets should just work:

  ```elixir
  def changeset(schema, attrs) do
    schema
    |> Changeset.cast(attrs, [:a, :b])
    |> Changeset.validate_required([:a, :b])
  end
  ```

  Framestamp.Range values can be cast from the following values in changesets:

  - [Framerate](`Vtc.Framestamp.Range`) structs.

  ## Fragments

  Framerate values must be explicitly cast using
  [type/2](https://hexdocs.pm/ecto/Ecto.Query.html#module-interpolation-and-casting):

  ```elixir
  stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  stamp_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
  stamp_range = Framestamp.new!(stamp_in, stamp_out)

  query = Query.from(
    f in fragment("SELECT ? as r", type(^stamp_range, Framerate.Range)), select: f.r
  )
  ```
  """

  use Ecto.Type

  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Framestamp

  @doc section: :ecto_migrations
  @doc """
  The database type for [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`).

  Can be used in migrations as the fields type.
  """
  @impl Ecto.Type
  @spec type() :: atom()
  def type, do: :framestamp_range

  @typedoc """
  Type of the raw composite value that will be sent to / received from the database.
  """
  @type db_record() :: %Postgrex.Range{
          lower: PgFramestamp.db_record(),
          lower_inclusive: boolean(),
          upper: PgFramestamp.db_record(),
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
  @spec load(db_record()) :: {:ok, Framestamp.Range.t()} | :error
  def load(%Postgrex.Range{} = db_record) do
    out_type = if db_record.upper_inclusive, do: :inclusive, else: :exclusive

    with {:ok, in_stamp} <- Framestamp.load(db_record.lower),
         in_stamp = if(db_record.lower_inclusive, do: in_stamp, else: Framestamp.add(in_stamp, 1)),
         {:ok, out_stamp} <- Framestamp.load(db_record.upper),
         {:ok, _} = result <- Framestamp.Range.new(in_stamp, out_stamp, out_type: out_type) do
      result
    else
      _ -> :error
    end
  end

  def load(_), do: :error

  # Handles converting `Framestamp.Range` structs into database records.
  @doc false
  @impl Ecto.Type
  @spec dump(Framestamp.Range.t()) :: {:ok, db_record()} | :error
  def dump(%Framestamp.Range{} = range) do
    with {:ok, in_stamp_record} <- PgFramestamp.dump(range.in),
         {:ok, out_stamp_record} <- PgFramestamp.dump(range.out) do
      db_record = %Postgrex.Range{
        lower: in_stamp_record,
        lower_inclusive: true,
        upper: out_stamp_record,
        upper_inclusive: range.out_type == :inclusive
      }

      {:ok, db_record}
    end
  end

  def dump(_), do: :error
end
