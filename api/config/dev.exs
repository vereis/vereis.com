import Config

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :plug_init_mode, :runtime

config :phoenix, :stacktrace_depth, 20

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true

config :vereis, Vereis.Repo,
  database: Path.expand("../vereis_dev.db", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :vereis, VereisWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "Tzg0oz5RVwKViQtUvf6VSKIRdZiMRZFe+bXFzSyuJHS54QpFqPkyLSOEB6O6Ch3F",
  watchers: []

config :vereis, dev_routes: true
