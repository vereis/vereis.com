defmodule Vereis.MixProject do
  use Mix.Project

  def project do
    [
      app: :vereis,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ]
    ]
  end

  def application do
    [
      mod: {Vereis.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test) do
    ["lib", "test/support"]
  end

  defp elixirc_paths(_) do
    ["lib"]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:absinthe, "~> 1.7"},
      {:absinthe_plug, "~> 1.5"},
      {:absinthe_relay, "~> 1.5"},
      {:absinthe_relay_keyset_connection, "~> 2.1"},
      {:dataloader, "~> 2.0"},
      {:tidewave, "~> 0.5", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.3", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:excellent_migrations, "~> 0.1", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:briefly, "~> 0.5.1", only: :test},
      {:yaml_elixir, "~> 2.11"},
      {:mdex, "~> 0.2"},
      {:floki, "~> 0.36"},
      {:html5ever, "~> 0.17"},
      {:polymorphic_embed, "~> 5.0"},
      {:vix, "~> 0.33"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      lint: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format --check-formatted",
        "credo --strict",
        "dialyzer",
        "sobelow --config",
        "excellent_migrations.check_safety"
      ]
    ]
  end
end
