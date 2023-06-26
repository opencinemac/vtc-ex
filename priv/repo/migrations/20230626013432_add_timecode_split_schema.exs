defmodule Vtc.Test.Support.Repo.Migrations.AddTimecodeSplitSchema do
  @moduledoc false
  use Ecto.Migration
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgRational

  def change do
    create table("split_timecodes", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)

      add(:a_seconds, PgRational.type())
      add(:a_rate, PgRational.type())
      add(:a_tags, {:array, :framerate_tags})

      add(:b_seconds, PgRational.type())
      add(:b_rate, PgRational.type())
      add(:b_tags, {:array, :framerate_tags})
    end
  end
end
