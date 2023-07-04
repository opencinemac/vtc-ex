defmodule Vtc.Test.Support.FramestampSchema01 do
  @moduledoc """
  Dummy schema for verifying the Postgres Repo in our test env
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias Vtc.Framestamp

  @type t() :: %__MODULE__{
          id: Ecto.UUID.t(),
          a: Framestamp.t(),
          b: Framestamp.t()
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "framestamps_01" do
    field(:a, Framestamp)
    field(:b, Framestamp)
  end

  @spec changeset(%__MODULE__{}, %{atom() => any()}) :: Changeset.t(%__MODULE__{})
  def changeset(schema, attrs), do: Changeset.cast(schema, attrs, [:a, :b])
end
