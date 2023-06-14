{:ok, _} = Application.ensure_all_started(:postgrex)

_ = Vtc.Test.Support.Repo.__adapter__().storage_down(Vtc.Test.Support.Repo.config())
:ok = Vtc.Test.Support.Repo.__adapter__().storage_up(Vtc.Test.Support.Repo.config())

{:ok, _} = Vtc.Test.Support.Repo.start_link()

Ecto.Migrator.run(Vtc.Test.Support.Repo, :up, all: true)
Ecto.Adapters.SQL.Sandbox.mode(Vtc.Test.Support.Repo, :manual)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()
