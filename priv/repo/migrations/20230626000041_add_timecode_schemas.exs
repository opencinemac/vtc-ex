defmodule Vtc.Test.Support.Repo.Migrations.AddTimecodeSchemas do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgTimecode

  def change do
    create table("timecodes_01", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:a, PgTimecode.type())
      add(:b, PgTimecode.type())
    end

    :ok = PgTimecode.Migrations.create_field_constraints("timecodes_01", :b)
  end
end
