use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramestamp.Range do
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
