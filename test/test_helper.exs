ExUnit.configure(autorun: false, formatters: [JUnitFormatter, ExUnit.CLIFormatter])

postgres_tags = MapSet.new([:postgres, :ecto])

exunit_config = ExUnit.configuration()
exclude = exunit_config |> Keyword.fetch!(:exclude) |> MapSet.new()
include = exunit_config |> Keyword.fetch!(:include) |> MapSet.new()

postgres? =
  cond do
    postgres_tags |> MapSet.intersection(exclude) |> MapSet.size() > 0 -> false
    :test in exclude and postgres_tags |> MapSet.intersection(include) |> MapSet.size() == 0 -> false
    true -> true
  end

if postgres? do
  db_config = Vtc.Test.Support.Repo.config()

  _ = Vtc.Test.Support.Repo.__adapter__().storage_down(db_config)
  :ok = Vtc.Test.Support.Repo.__adapter__().storage_up(db_config)

  {:ok, _} = Vtc.Test.Support.Repo.start_link(db_config)

  # Rollback migrations and re-run to test that rollbacks are working correctly.
  Ecto.Migrator.run(Vtc.Test.Support.Repo, :up, all: true)
  Ecto.Migrator.run(Vtc.Test.Support.Repo, :down, all: true)
  Ecto.Migrator.run(Vtc.Test.Support.Repo, :up, all: true)

  Ecto.Adapters.SQL.Sandbox.mode(Vtc.Test.Support.Repo, :manual)
end
