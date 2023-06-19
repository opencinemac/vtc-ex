import Config

config :vtc,
  env: config_env(),
  include_postgres_types?: true

import_config "#{config_env()}.exs"
