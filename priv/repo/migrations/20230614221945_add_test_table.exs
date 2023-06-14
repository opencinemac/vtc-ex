defmodule Vtc.Test.Support.Repo.Migrations.AddTestTable do
  @moduledoc """
  Adds a test table for verifying that the Postgres connection in our testing env
  works.
  """
  use Ecto.Migration

  def change do
    create table("movies", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:name, :string)
      add(:release_year, :integer)
    end
  end
end
