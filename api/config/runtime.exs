import Config

if System.get_env("PHX_SERVER") do
  config :vereis, VereisWeb.Endpoint, server: true
end

default_ip = if config_env() == :prod, do: "::", else: "127.0.0.1"

http_ip =
  case System.get_env("HTTP_IP", default_ip) do
    "::" ->
      {0, 0, 0, 0, 0, 0, 0, 0}

    ip_string ->
      ip_string
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
      |> List.to_tuple()
  end

config :vereis, VereisWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT", "4000")),
    ip: http_ip
  ]

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/vereis/vereis.db
      """

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :vereis, Vereis.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  config :vereis, VereisWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    secret_key_base: secret_key_base

  config :vereis, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
end
