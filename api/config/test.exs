import Config

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix,
  sort_verified_routes_query_params: true

config :vereis, Vereis.Repo,
  database: Path.expand("../vereis_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox,
  timeout: 30_000,
  ownership_timeout: 30_000,
  default_transaction_mode: :immediate

config :vereis, VereisWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "fRQM2wGUHqd53kda4miz9IzKMpBboTslX5UbDZ447yVsPTozBrUlULO9+OBkmt9i",
  server: false
