use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramestamp do
  @moduledoc """
  Defines a composite type for storing rational values as a
  [PgRational](`Vtc.Ecto.Postgres.PgRational`) real-world playbck seconds,
  [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`) pair.

  These values are cast to
  [Framestamp](`Vtc.Framestamp`) structs for use in application code.

  The composite types is defined as follows:

  ```sql
  CREATE TYPE framestamp as (
    seconds rational,
    rate framerate
  )
  ```

  ```sql
  SELECT ((18018, 5), ((24000, 1001), '{non_drop}'))::framestamp
  ```

  ## Field migrations

  You can create `framerate` fields during a migration like so:

  ```elixir
  alias Vtc.Framestamp

  create table("events") do
    add(:in, Framestamp.type())
    add(:out, Framestamp.type())
  end
  ```

  [Framestamp](`Vtc.Framestamp`) re-exports the `Ecto.Type` implementation of this module,
  and can be used any place this module would be used.

  ## Schema fields

  Then in your schema module:

  ```elixir
  defmodule MyApp.Event do
  @moduledoc false
  use Ecto.Schema

  alias Vtc.Framestamp

  @type t() :: %__MODULE__{
          in: Framestamp.t(),
          out: Framestamp.t()
        }

  schema "events" do
    field(:in, Framestamp)
    field(:out, Framestamp)
  end
  ```

  ## Changesets

  With the above setup, changesets should just work:

  ```elixir
  def changeset(schema, attrs) do
    schema
    |> Changeset.cast(attrs, [:in, :out])
    |> Changeset.validate_required([:in, :out])
  end
  ```

  Framerate values can be cast from the following values in changesets:

  - [Framestamp](`Vtc.Framestamp`) structs.

  - Maps with the following format:

    ```json
    {
      "smpte_timecode": "01:00:00:00",
      "rate": {
        "playback": [24000, 1001],
        "ntsc": "non_drop"
      }
    }
    ```

    Where `smpte_timecode` is properly formatted SMPTE timecode string and `playback`
    is a map value supported by [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`) changeset
    casts.

  ## Fragments

  Framestamp values must be explicitly cast using
  [type/2](https://hexdocs.pm/ecto/Ecto.Query.html#module-interpolation-and-casting):

  ```elixir
  framestamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  query = Query.from(f in fragment("SELECT ? as r", type(^framestamp, Framestamp)), select: f.r)
  ```
  """

  use Ecto.Type

  alias Ecto.Changeset
  alias Vtc.Ecto.Postgres.PgFramerate
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Source.Frames.SMPTETimecodeStr

  @doc section: :ecto_migrations
  @doc """
  The database type for [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`).

  Can be used in migrations as the fields type.
  """
  @impl Ecto.Type
  @spec type() :: atom()
  def type, do: :framestamp

  @typedoc """
  Type of the raw composite value that will be sent to / received from the database.
  """
  @type db_record() :: {PgRational.db_record(), PgFramerate.db_record()}

  # Handles casting PgRational fields in `Ecto.Changeset`s.
  @doc false
  @impl Ecto.Type
  @spec cast(Framestamp.t() | %{String.t() => any()} | %{atom() => any()}) :: {:ok, Framerate.t()} | :error
  def cast(%Framestamp{} = framestamp), do: {:ok, framestamp}

  def cast(json) when is_map(json) do
    schema = %{
      smpte_timecode: :string,
      rate: Framerate
    }

    changeset =
      {%{}, schema}
      |> Changeset.cast(json, [:smpte_timecode, :rate])
      |> Changeset.validate_required([:smpte_timecode, :rate])

    with {:ok, %{smpte_timecode: timecode_str, rate: rate}} <- Changeset.apply_action(changeset, :loaded),
         {:ok, _} = result <- Framestamp.with_frames(%SMPTETimecodeStr{in: timecode_str}, rate) do
      result
    else
      _ -> :error
    end
  end

  def cast(_), do: :error

  # Handles converting database records into Ratio structs to be used by the
  # application.
  @doc false
  @impl Ecto.Type
  @spec load(db_record()) :: {:ok, Framestamp.t()} | :error
  def load({seconds, rate}) do
    with {:ok, seconds} <- PgRational.load(seconds),
         {:ok, framerate} <- PgFramerate.load(rate),
         {:ok, _} = result <- Framestamp.with_seconds(seconds, framerate, round: :off) do
      result
    else
      _ -> :error
    end
  end

  def load(_), do: :error

  # Handles converting Ratio structs into database records.
  @doc false
  @impl Ecto.Type
  @spec dump(Framestamp.t()) :: {:ok, db_record()} | :error
  def dump(%Framestamp{} = framestamp) do
    with {:ok, seconds} <- PgRational.dump(framestamp.seconds),
         {:ok, framerate} <- PgFramerate.dump(framestamp.rate) do
      {:ok, {seconds, framerate}}
    end
  end

  def dump(_), do: :error
end
