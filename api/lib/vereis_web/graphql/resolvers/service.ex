defmodule VereisWeb.GraphQL.Resolvers.Service do
  @moduledoc "Resolvers for the service."

  alias Vereis.Service

  def get(_parent, _args, _resolution) do
    {:ok, Service.get()}
  end

  def sha(%Service{sha: sha}, _args, _resolution) do
    {:ok, sha}
  end

  def env(%Service{env: env}, _args, _resolution) do
    {:ok, env}
  end

  def liveness(%Service{liveness: liveness}, _args, _resolution) do
    {:ok, liveness}
  end

  def readiness(%Service{readiness: readiness}, _args, _resolution) do
    {:ok, readiness}
  end

  def node(%{type: :service, id: _id}, _resolution) do
    {:ok, Service.get()}
  end
end
