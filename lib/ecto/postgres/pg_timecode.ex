use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgTimecode do
  @moduledoc """
  Defines a composite type for storing rational values as a
  [PgRational](`Vtc.Ecto.Postgres.PgRational`) real-world playbck seconds,
  [PgFramerate](`Vtc.Ecto.Postgres.Framerate`) playback rate pair.

  These values are cast to
  [Timecode](`Vtc.Timecode`) structs for use in application code.

  The composite types is defined as follows:

  ```sql
  CREATE TYPE timecode as (
    seconds rational,
    rate framerate
  )
  ```

  ```sql
  SELECT ((10, 1), ((24, 1), '{non_drop}'))::timecode
  ```

  ## Field migrations

  You can create `framerate` fields during a migration like so:

  ```elixir
  alias Vtc.Timecode

  create table("events") do
    add(:in, Timecode.type())
    add(:out, Timecode.type())
  end
  ```

  [Timecode](`Vtc.Timecode`) re-exports the `Ecto.Type` implementation of this module,
  and can be used any place this module would be used.

  ## Schema fields

  Then in your schema module:

  ```elixir
  defmodule MyApp.Event do
  @moduledoc false
  use Ecto.Schema

  alias Vtc.Timecode

  @type t() :: %__MODULE__{
          in: Timecode.t(),
          out: Timecode.t()
        }

  schema "events" do
    field(:in, Timecode)
    field(:out, Timecode)
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

  - [Timecode](`Vtc.Timecode`) structs.

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

  Timecode values must be explicitly cast using
  [type/2](https://hexdocs.pm/ecto/Ecto.Query.html#module-interpolation-and-casting):

  ```elixir
  timecode = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  query = Query.from(f in fragment("SELECT ? as r", type(^timecode, Timecode)), select: f.r)
  ```
  """

  use Ecto.Type

  alias Ecto.Changeset
  alias Vtc.Ecto.Postgres.PgFramerate
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Framerate
  alias Vtc.Source.Frames.TimecodeStr
  alias Vtc.Timecode

  @doc section: :ecto_migrations
  @doc """
  The database type for [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`).

  Can be used in migrations as the fields type.
  """
  @impl Ecto.Type
  def type, do: :timecode

  @typedoc """
  Type of the raw composite value that will be sent to / received from the database.
  """
  @type db_record() :: {PgRational.db_record(), PgFramerate.db_record()}

  # Handles casting PgRational fields in `Ecto.Changeset`s.
  @doc false
  @impl Ecto.Type
  @spec cast(Timecode.t() | %{String.t() => any()} | %{atom() => any()}) :: {:ok, Framerate.t()} | :error
  def cast(%Timecode{} = timecode), do: {:ok, timecode}

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
         {:ok, _} = result <- Timecode.with_frames(%TimecodeStr{in: timecode_str}, rate) do
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
  @spec load(db_record()) :: {:ok, Timecode.t()} | :error
  def load({seconds, rate}) do
    with {:ok, seconds} <- PgRational.load(seconds),
         {:ok, framerate} <- PgFramerate.load(rate),
         {:ok, _} = result <- Timecode.with_seconds(seconds, framerate, round: :off) do
      result
    else
      _ -> :error
    end
  end

  def load(_), do: :error

  # Handles converting Ratio structs into database records.
  @doc false
  @impl Ecto.Type
  @spec dump(Timecode.t()) :: {:ok, db_record()} | :error
  def dump(%Timecode{} = timecode) do
    with {:ok, seconds} <- PgRational.dump(timecode.seconds),
         {:ok, framerate} <- PgFramerate.dump(timecode.rate) do
      {:ok, {seconds, framerate}}
    end
  end

  def dump(_), do: :error
end
