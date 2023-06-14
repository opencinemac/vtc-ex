defmodule Vtc.Ecto.Postgres.RepoTest do
  @moduledoc """
  General tests that postgres is working in the test env.
  """
  use Vtc.Test.Support.EctoCase, async: true

  alias Vtc.Test.Support.MoviesSchema

  test "check repo connection" do
    assert {:ok, %Postgrex.Result{rows: [[1]]}} = Repo.query("SELECT 1")
  end

  @static_id Ecto.UUID.generate()

  test "can insert schema" do
    assert {:ok, record} =
             %MoviesSchema{id: @static_id}
             |> MoviesSchema.changeset(%{name: "Star Wars", release_year: 1977})
             |> Repo.insert()

    assert %MoviesSchema{id: @static_id} = record
  end

  test "cannot fetch record from previous test" do
    assert Repo.get(MoviesSchema, @static_id) == nil
  end
end
