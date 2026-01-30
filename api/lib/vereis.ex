defmodule Vereis do
  @moduledoc """
  Root namespace module for the Vereis application.
  Delegates to Vereis.Service for version and environment information.
  """

  alias Vereis.Service

  @doc "Returns the git SHA of the current version."
  @spec version() :: String.t()
  defdelegate version(), to: Service

  @doc "Returns the deployment environment."
  @spec env() :: String.t()
  defdelegate env(), to: Service
end
