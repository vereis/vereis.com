defmodule Vereis.Service do
  @moduledoc "Represents the running API service instance."

  alias Vereis.Repo

  # id exists only for Relay GraphQL node interface
  @service_id "service:api"

  defstruct [
    :id,
    :sha,
    :env,
    :liveness,
    :readiness
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          sha: String.t(),
          env: String.t(),
          liveness: boolean(),
          readiness: boolean()
        }

  @doc "Returns service information."
  @spec get() :: t()
  def get do
    %__MODULE__{
      id: @service_id,
      sha: version(),
      env: env(),
      liveness: liveness?(),
      readiness: readiness?()
    }
  end

  @doc "Returns service's current version."
  @spec version() :: String.t()
  def version do
    release_sha = System.get_env("RELEASE_SHA")

    if release_sha in [nil, ""] do
      "git"
      |> System.cmd(["rev-parse", "HEAD"])
      |> then(fn {sha, 0} -> String.trim(sha) end)
    else
      release_sha
    end
  end

  @doc "Returns the deployment environment."
  @spec env() :: String.t()
  def env do
    System.get_env("DEPLOYMENT_ENV") || Atom.to_string(Application.get_env(:vereis, :env))
  end

  @doc "Is the service running?"
  @spec liveness?() :: boolean()
  def liveness? do
    true
  end

  @doc "Is the service ready to serve traffic?"
  @spec readiness?() :: boolean()
  def readiness? do
    match?({:ok, _resp}, Repo.query("SELECT 1", []))
  end
end
