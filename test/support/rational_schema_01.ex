defmodule Vtc.Test.Support.RationalsSchema01 do
  @moduledoc """
  Dummy schema for verifying the Postgres Repo in our test env
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

  schema "rationals_01" do
    field(:a, PgRational)
    field(:b, PgRational)
  end

  @spec changeset(%__MODULE__{}, %{atom() => any()}) :: Changeset.t(%__MODULE__{})
  def changeset(schema, attrs) do
    schema
    |> Changeset.cast(attrs, [:a, :b])
    |> Changeset.validate_required([:a, :b])
  end
end
