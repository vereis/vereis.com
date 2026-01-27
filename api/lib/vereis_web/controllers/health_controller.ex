defmodule VereisWeb.HealthController do
  use VereisWeb, :controller

  alias Vereis.Health

  @doc """
  Always returns 200 OK if we're executing code.
  """
  def liveness(conn, _params) do
    json(conn, %{status: "ok"})
  end

  @doc """
  Returns 200 OK if all dependencies (database) are healthy.
  Returns 503 Service Unavailable if any dependency is unhealthy.
  """
  def readiness(conn, _params) do
    case Health.readiness() do
      :ok ->
        json(conn, %{status: "ok", database: "connected"})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", database: "disconnected", reason: reason})
    end
  end
end
