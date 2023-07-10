import Config

config :vtc, Vtc.Test.Support.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "vtc_test",
  log: false,
  vtc: [
    rational: [
      functions_schema: :rational,
      functions_prefix: ""
    ],
    framerate: [
      functions_schema: :framerate,
      functions_prefix: ""
    ],
    framestamp: [
      functions_schema: :framestamp,
      functions_prefix: ""
    ],
    framestamp_range: [
      functions_schema: :framestamp_range,
      functions_prefix: ""
    ]
  ]

config :vtc,
  ecto_repos: [Vtc.Test.Support.Repo]
