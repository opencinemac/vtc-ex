defmodule Vtc.Test.Support.RationalsSchema02 do
  @moduledoc """
  Dummy schema for testing PgRational values in our database.
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias Vtc.Ecto.Postgres.PgRational

  @type t() :: %__MODULE__{
          id: Ecto.UUID.t(),
          a: Ratio.t(),
          b: Ratio.t()
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "rationals_02" do
    field(:a, PgRational)
    field(:b, PgRational)
  end

  @spec changeset(%__MODULE__{}, %{atom() => any()}) :: Changeset.t()
  def changeset(schema, attrs) do
    schema
    |> Changeset.cast(attrs, [:a, :b])
    |> Changeset.validate_required([:a, :b])
  end
end
