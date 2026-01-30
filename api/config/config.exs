# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# SQLite doesn't support concurrent index creation
config :excellent_migrations,
  skip_checks: [:index_not_concurrently]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :vereis, Oban,
  engine: Oban.Engines.Lite,
  repo: Vereis.Repo,
  queues: [imports: 1],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"@reboot", Vereis.Importer}
     ]}
  ]

# Configure the endpoint
config :vereis, VereisWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: VereisWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Vereis.PubSub,
  live_view: [signing_salt: "KU5b+ErJ"]

config :vereis,
  ecto_repos: [Vereis.Repo],
  generators: [timestamp_type: :utc_datetime],
  env: config_env(),
  content_dir: "priv/content"

import_config "#{config_env()}.exs"
