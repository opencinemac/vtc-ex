defmodule Vtc.Test.Support.SplitTimecodesSchema do
  @moduledoc """
  Dummy schema for verifying the Postgres Repo in our test env
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias Vtc.Ecto.Postgres.PgRational

  @type t() :: %__MODULE__{
          id: Ecto.UUID.t(),
          a_seconds: Ratio.t(),
          a_rate: Ratio.t(),
          a_tags: [String.t()],
          b_seconds: Ratio.t(),
          b_rate: Ratio.t(),
          b_tags: [String.t()]
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "split_timecodes" do
    field(:a_seconds, PgRational)
    field(:a_rate, PgRational)
    field(:a_tags, {:array, :string})
    field(:b_seconds, PgRational)
    field(:b_rate, PgRational)
    field(:b_tags, {:array, :string})
  end

  @spec changeset(%__MODULE__{}, %{atom() => any()}) :: Changeset.t(%__MODULE__{})
  def changeset(schema, attrs) do
    schema
    |> Changeset.cast(attrs, [:a_seconds, :a_rate, :a_tags, :b_seconds, :b_rate, :b_tags])
    |> Changeset.validate_required([:a_seconds, :a_rate, :a_tags, :b_seconds, :b_rate, :b_tags])
  end
end
