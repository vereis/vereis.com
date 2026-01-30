defmodule VereisWeb.ServiceController do
  use VereisWeb, :controller

  alias Vereis.Service

  @doc "Returns version and environment information for the API."
  def version(conn, _params) do
    json(conn, Map.take(Service.get(), [:sha, :env]))
  end

  @doc "Always returns 200 OK if we're executing code."
  def liveness(conn, _params) do
    json(conn, %{status: "ok"})
  end

  @doc """
  Returns 200 OK if all dependencies (database) are healthy.
  Returns 503 Service Unavailable if any dependency is unhealthy.
  """
  def readiness(conn, _params) do
    if Service.readiness?() do
      json(conn, %{status: "ok", database: "connected"})
    else
      conn
      |> put_status(:service_unavailable)
      |> json(%{status: "error", database: "disconnected"})
    end
  end
end
