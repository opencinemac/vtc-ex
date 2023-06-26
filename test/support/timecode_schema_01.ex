defmodule Vtc.Test.Support.TimecodeSchema01 do
  @moduledoc """
  Dummy schema for verifying the Postgres Repo in our test env
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias Vtc.Timecode

  @type t() :: %__MODULE__{
          id: Ecto.UUID.t(),
          a: Timecode.t(),
          b: Timecode.t()
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "timecodes_01" do
    field(:a, Timecode)
    field(:b, Timecode)
  end

  @spec changeset(%__MODULE__{}, %{atom() => any()}) :: Changeset.t(%__MODULE__{})
  def changeset(schema, attrs), do: Changeset.cast(schema, attrs, [:a, :b])
end
