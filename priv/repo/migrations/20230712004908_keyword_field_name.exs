defmodule Vtc.Test.Support.Repo.Migrations.KeywordFieldName do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgFramerate
  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Ecto.Postgres.PgRational
  alias Vtc.Framerate
  alias Vtc.Framestamp

  def change do
    create table("rational_keyword_fieldnames_constraints", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:in, PgRational.type())
      add(:end, PgRational.type())
    end

    PgRational.Migrations.create_constraints("rational_keyword_fieldnames_constraints", :in)
    PgRational.Migrations.create_constraints("rational_keyword_fieldnames_constraints", :end)

    create table("framerate_keyword_fieldnames_constraints", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:in, Framerate.type())
      add(:end, Framerate.type())
    end

    PgFramerate.Migrations.create_constraints("framerate_keyword_fieldnames_constraints", :in)
    PgFramerate.Migrations.create_constraints("framerate_keyword_fieldnames_constraints", :end)

    create table("framestamp_keyword_fieldnames_constraints", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:in, Framestamp.type())
      add(:end, Framestamp.type())
    end

    PgFramestamp.Migrations.create_constraints("framestamp_keyword_fieldnames_constraints", :in)
    PgFramestamp.Migrations.create_constraints("framestamp_keyword_fieldnames_constraints", :end)
  end
end
