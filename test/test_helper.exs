ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])

postgres_tags = MapSet.new([:postgres, :ecto])

exunit_config = ExUnit.configuration()
exclude = exunit_config |> Keyword.fetch!(:exclude) |> MapSet.new()
include = exunit_config |> Keyword.fetch!(:include) |> MapSet.new()

cond do
  postgres_tags |> MapSet.intersection(exclude) |> MapSet.size() > 0 ->
    :ok

  :test in exclude and postgres_tags |> MapSet.intersection(include) |> MapSet.size() == 0 ->
    :ok

  true ->
    {:ok, _} = Application.ensure_all_started(:postgrex)

    _ = Vtc.Test.Support.Repo.__adapter__().storage_down(Vtc.Test.Support.Repo.config())
    :ok = Vtc.Test.Support.Repo.__adapter__().storage_up(Vtc.Test.Support.Repo.config())

    {:ok, _} = Vtc.Test.Support.Repo.start_link()

    Ecto.Migrator.run(Vtc.Test.Support.Repo, :up, all: true)
    Ecto.Adapters.SQL.Sandbox.mode(Vtc.Test.Support.Repo, :manual)
end

ExUnit.start()
