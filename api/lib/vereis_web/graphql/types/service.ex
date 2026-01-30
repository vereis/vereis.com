defmodule VereisWeb.GraphQL.Types.Service do
  @moduledoc "GraphQL schema definition for service status."

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias VereisWeb.GraphQL.Resolvers

  @desc "The running API service instance"
  node object(:service) do
    @desc "Git SHA of the deployed version"
    field :sha, non_null(:string), resolve: &Resolvers.Service.sha/3

    @desc "Build environment of the service"
    field :env, non_null(:string), resolve: &Resolvers.Service.env/3

    @desc "Is the service running?"
    field :liveness, non_null(:boolean), resolve: &Resolvers.Service.liveness/3

    @desc "Is the service ready to serve traffic?"
    field :readiness, non_null(:boolean), resolve: &Resolvers.Service.readiness/3
  end
end
