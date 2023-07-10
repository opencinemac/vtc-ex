import Config

config :vtc,
  env: config_env()

config :vtc, Postgrex, include?: true

import_config "#{config_env()}.exs"
