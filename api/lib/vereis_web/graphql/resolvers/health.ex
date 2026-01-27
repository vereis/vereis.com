defmodule VereisWeb.GraphQL.Resolvers.Health do
  @moduledoc "GraphQL resolvers for health checks."

  alias Vereis.Health

  @doc "Liveness check - see `Health.liveness/0`"
  def liveness(_parent, _args, _resolution) do
    :ok = Health.liveness()
    {:ok, true}
  end

  @doc "Readiness check - see `Health.readiness/0`"
  def readiness(_parent, _args, _resolution) do
    case Health.readiness() do
      :ok -> {:ok, true}
      {:error, _reason} -> {:ok, false}
    end
  end
end
