import Config

config :logger, level: :info

config :vereis, VereisWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  exclude: [
    hosts: ["localhost", "127.0.0.1"]
  ]

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
