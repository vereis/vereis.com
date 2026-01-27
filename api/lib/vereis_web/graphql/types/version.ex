defmodule VereisWeb.GraphQL.Types.Version do
  @moduledoc "API version information."

  use Absinthe.Schema.Notation

  @desc "Version information for the API"
  object :version do
    @desc "The current version of the API"
    field :sha, non_null(:string) do
      resolve(&VereisWeb.GraphQL.Resolvers.Version.sha/3)
    end

    @desc "The build environment of the API"
    field :env, non_null(:string) do
      resolve(&VereisWeb.GraphQL.Resolvers.Version.env/3)
    end
  end
end
