defmodule Vtc.Test.Support.MoviesSchema do
  @moduledoc """
  Dummy schema for verifying the Postgres Repo in our test env
  """
  use Ecto.Schema

  alias Ecto.Changeset

  @type t() :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          release_year: pos_integer()
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "movies" do
    field(:name, :string)
    field(:release_year, :integer)
  end

  @spec changeset(%__MODULE__{}, %{atom() => any()}) :: Changeset.t()
  def changeset(schema, attrs) do
    schema
    |> Changeset.cast(attrs, [:name, :release_year])
    |> Changeset.validate_required([:name, :release_year])
  end
end
