use Vtc.Ecto.Postgres.Utils

defpgmodule Vtc.Ecto.Postgres.PgFramerate do
  @moduledoc """
  Defines a composite type for storing rational values as a
  [PgRational](`Vtc.Ecto.Postgres.PgRational`) + list of tags. These values are cast to
  [Framerate](`Vtc.Framerate`) structs for use in application code.

  The composite types are defined as follows:

  ```sql
  CREATE TYPE framerate_tags AS ENUM (
    "drop",
    "non_drop"
  )
  ```

  ```sql
  CREATE TYPE framerate as (
    playback rational,
    tags framerate_tags[]
  )
  ```

  `framerate_tags` is designed as such to guarantee forwards-compatibility with future
  support for features like interlaced timecode.

  Framerate values can be cast in SQL expressions like so:

  ```sql
  SELECT ((24000, 1001), '{non_drop}')::framerate
  ```

  ## Framerate tags

  The following values are valid tags:

  - `drop`: Indicates NTSC, drop-frame timecode
  - `non_drop`: Indicated NTSC, non-drop timecode

  ## Field migrations

  You can create `framerate` fields during a migration like so:

  ```elixir
  alias Vtc.Framerate

  create table("rationals") do
    add(:a, Framerate.type())
    add(:b, Framerate.type())
  end
  ```

  [Framerate](`Vtc.Framerate`) re-exports the `Ecto.Type` implementation of this module,
  and can be used any place this module would be used.

  ## Schema fields

  Then in your schema module:

  ```elixir
  defmodule MyApp.Framerates do
  @moduledoc false
  use Ecto.Schema

  alias Vtc.Framerate

  @type t() :: %__MODULE__{
          a: Framerate.t(),
          b: Framerate.t()
        }

  schema "rationals_01" do
    field(:a, Framerate)
    field(:b, Framerate)
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

  Framerate values can be cast from the following values in changesets:

  - [Framerate](`Vtc.Framerate`) structs.

  - Maps with the following format:

    ```json
    {
      "playback": [24000, 1001],
      "ntsc": "non_drop"
    }
    ```

    Where `playback` is a value supported by
    [PgRational](`Vtc.Ecto.Postgres.PgRational`) casting and `ntsc` can be `null`,
    `"drop"` or `"non_drop"`.

  ## Fragments

  Framerate values must be explicitly cast using
  [type/2](https://hexdocs.pm/ecto/Ecto.Query.html#module-interpolation-and-casting):

  ```elixir
  framerate = Rates.f23_98()
  query = Query.from(f in fragment("SELECT ? as r", type(^framerate, Framerate)), select: f.r)
  ```
  """

  use Ecto.Type

  alias Ecto.Changeset
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Framerate

  @doc section: :ecto_migrations
  @doc """
  The database type for [PgFramerate](`Vtc.Ecto.Postgres.PgFramerate`).

  Can be used in migrations as the fields type.
  """
  @impl Ecto.Type
  @spec type() :: atom()
  def type, do: :framerate

  @typedoc """
  Type of the raw composite value that will be sent to / received from the database.
  """
  @type db_record() :: {PgRational.db_record(), [String.t()]}

  # Handles casting PgRational fields in `Ecto.Changeset`s.
  @doc false
  @impl Ecto.Type
  @spec cast(Framerate.t() | %{String.t() => any()} | %{atom() => any()}) :: {:ok, Framerate.t()} | :error
  def cast(%Framerate{} = framerate), do: {:ok, framerate}

  def cast(json) when is_map(json) do
    schema = %{
      playback: PgRational,
      ntsc: {:parameterized, Ecto.Enum, Ecto.Enum.init(values: [:drop, :non_drop])}
    }

    changeset =
      {%{}, schema}
      |> Changeset.cast(json, [:playback, :ntsc])
      |> Changeset.validate_required([:playback])

    with {:ok, loaded} <- Changeset.apply_action(changeset, :loaded),
         {:ok, _} = result <- Framerate.new(loaded.playback, ntsc: Map.get(loaded, :ntsc, nil)) do
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
  @spec load(db_record()) :: {:ok, Framerate.t()} | :error
  def load({rate, tags}) when is_list(tags) do
    ntsc = load_ntsc(tags)

    with {:ok, rate_loaded} <- PgRational.load(rate),
         {:ok, _} = result <- Framerate.new(rate_loaded, ntsc: ntsc) do
      result
    else
      _ -> :error
    end
  end

  def load(_), do: :error

  @spec load_ntsc([String.t()]) :: Framerate.ntsc()
  defp load_ntsc(tags) do
    cond do
      "drop" in tags -> :drop
      "non_drop" in tags -> :non_drop
      true -> nil
    end
  end

  # Handles converting Ratio structs into database records.
  @doc false
  @impl Ecto.Type
  @spec dump(Framerate.t()) :: {:ok, db_record()} | :error
  def dump(%Framerate{} = framerate) do
    with {:ok, rational} <- PgRational.dump(framerate.playback) do
      tags = dump_tags_add_ntsc([], framerate)
      {:ok, {rational, tags}}
    end
  end

  def dump(_), do: :error

  @spec dump_tags_add_ntsc([String.t()], Framerate.t()) :: [String.t()]
  defp dump_tags_add_ntsc(tags, %{ntsc: :non_drop}), do: ["non_drop" | tags]
  defp dump_tags_add_ntsc(tags, %{ntsc: :drop}), do: ["drop" | tags]
  defp dump_tags_add_ntsc(tags, _), do: tags
end
