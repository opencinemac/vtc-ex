import Config

config :vtc, env: config_env()

import_config "#{config_env()}.exs"
