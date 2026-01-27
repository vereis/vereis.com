defmodule VereisWeb.GraphQL.Resolvers.Version do
  @moduledoc """
  Resolvers for API version information.
  """

  @doc "Returns the git SHA of the current version."
  def sha(_parent, _args, _resolution) do
    {:ok, Vereis.version()}
  end

  @doc "Returns the build environment of the API."
  def env(_parent, _args, _resolution) do
    {:ok, Atom.to_string(Vereis.env())}
  end
end
