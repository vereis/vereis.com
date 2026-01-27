defmodule Vereis.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      VereisWeb.Telemetry,
      Vereis.Repo,
      {Ecto.Migrator, repos: Application.fetch_env!(:vereis, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:vereis, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Vereis.PubSub},
      VereisWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Vereis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def config_change(changed, _new, removed) do
    VereisWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations? do
    System.get_env("RELEASE_NAME") == nil
  end
end
