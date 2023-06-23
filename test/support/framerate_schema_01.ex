defmodule Vtc.Test.Support.FramerateSchema01 do
  @moduledoc """
  Dummy schema for verifying the Postgres Repo in our test env
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias Vtc.Ecto.Postgres.PgFramerate
  alias Vtc.Framerate

  @type t() :: %__MODULE__{
          id: Ecto.UUID.t(),
          a: Framerate.t(),
          b: Framerate.t()
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "framerates_01" do
    field(:a, PgFramerate)
    field(:b, PgFramerate)
  end

  @spec changeset(%__MODULE__{}, %{atom() => any()}) :: Changeset.t(%__MODULE__{})
  def changeset(schema, attrs), do: Changeset.cast(schema, attrs, [:a, :b])
end
