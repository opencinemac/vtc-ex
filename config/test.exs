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
    pg_rational: [
      functions_schema: :rational,
      functions_private_schema: :rational_private,
      functions_prefix: ""
    ],
    pg_framerate: [
      functions_schema: :framerate,
      functions_private_schema: :framerate_private,
      functions_prefix: ""
    ],
    pg_framestamp: [
      functions_schema: :framestamp,
      functions_private_schema: :framestamp_private,
      functions_prefix: ""
    ]
  ]

config :vtc,
  ecto_repos: [Vtc.Test.Support.Repo]
