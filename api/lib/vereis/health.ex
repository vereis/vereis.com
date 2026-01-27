defmodule Vereis.Health do
  @moduledoc """
  Provides both liveness and readiness checks for the application.
  - Liveness: Is the application process running? (always true if we're executing code)
  - Readiness: Can the application serve traffic? (requires database connectivity)
  """

  alias Vereis.Repo

  @doc "Verifies if the application is alive."
  @spec liveness() :: :ok
  def liveness do
    :ok
  end

  @doc "Verifies if the application is ready to serve traffic."
  @spec readiness() :: :ok | {:error, String.t()}
  def readiness do
    case Repo.query("SELECT 1", []) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, Exception.message(reason)}
    end
  end
end
