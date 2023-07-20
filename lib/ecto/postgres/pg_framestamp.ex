use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramestamp do
  @moduledoc """
  Defines a composite type for storing rational values as a
  [PgRational](`Vtc.Ecto.Postgres.PgRational`) real-world playback seconds,
  [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`) pair.

  These values are cast to
  [Framestamp](`Vtc.Framestamp`) structs for use in application code.

  The composite types is defined as follows:

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
  > the seconds / rate values, see
  > [create_func_seconds/0](`Vtc.Ecto.Postgres.PgFramestamp.Migrations.create_func_seconds/0`),
  > [create_func_rate/0](`Vtc.Ecto.Postgres.PgFramestamp.Migrations.create_func_seconds/0`),
  > which create Postgres functions to act as getter functions for working with inner
  > framestamp data.

  ```sql
  SELECT (18018, 5, 24000, 1001, '{non_drop}')::framestamp
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
  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Source.Frames.SMPTETimecodeStr

  @doc section: :ecto_migrations
  @doc """
  The database type for [PgFramestamp](`Vtc.Ecto.Postgres.PgFramestamp`).

  Can be used in migrations as the fields type.
  """
  @impl Ecto.Type
  @spec type() :: atom()
  def type, do: :framestamp

  @typedoc """
  Type of the raw composite value that will be sent to / received from the database.
  """
  @type db_record() :: {non_neg_integer(), pos_integer(), non_neg_integer(), pos_integer(), [String.t()]}

  @doc """
  The database type for [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`).

  Can be used in migrations as the fields type.
  """
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
  def load({seconds_n, seconds_d, rate_n, rate_d, rate_tags}) do
    seconds = Ratio.new(seconds_n, seconds_d)

    with {:ok, framerate} <- PgFramerate.load({{rate_n, rate_d}, rate_tags}),
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
    with {:ok, {{rate_n, rate_d}, rate_tags}} <- PgFramerate.dump(framestamp.rate) do
      {:ok, {framestamp.seconds.numerator, framestamp.seconds.denominator, rate_n, rate_d, rate_tags}}
    end
  end

  def dump(_), do: :error

  @doc section: :changeset_validators
  @doc """
  Adds all constraints created by
  [PgFramestamp.Migrations.create_constraints/3](`Vtc.Ecto.Postgres.PgFramestamp.Migrations.create_constraints/3`)
  to changeset.

  ## Arguments

  - `changeset`: The changeset being validated.

  - `field`: The field who's constraints are being checked.

  ## Options

  Pass the same options that were passed to
  [PgFramestamp.Migrations.create_constraints/3](`Vtc.Ecto.Postgres.PgFramestamp.Migrations.create_constraints/3`)
  """
  @spec validate_constraints(Changeset.t(data), atom(), [PgFramestamp.Migrations.constraint_opt()]) :: Changeset.t(data)
        when data: any()
  def validate_constraints(changeset, field, opts \\ []) do
    "dummy_table"
    |> PgFramestamp.Migrations.build_constraint_list(field, opts)
    |> Enum.reduce(changeset, fn constraint, changeset ->
      Changeset.check_constraint(changeset, field, name: constraint.name)
    end)
  end
end
