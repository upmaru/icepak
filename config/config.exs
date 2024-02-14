import Config

config :tesla,
       :adapter,
       {Tesla.Adapter.Finch, name: Pakman.Finch, receive_timeout: 30_000}

import_config "#{config_env()}.exs"
