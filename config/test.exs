import Config

config :vtc, Vtc.Test.Support.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "vtc_test"

config :vtc,
  ecto_repos: [Vtc.Test.Support.Repo]
