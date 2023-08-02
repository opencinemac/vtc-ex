import Config

config :vtc,
  env: config_env(),
  include_test_utils?: true

config :vtc, Postgrex, include?: true

import_config "#{config_env()}.exs"
