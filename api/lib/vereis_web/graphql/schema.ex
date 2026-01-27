defmodule VereisWeb.GraphQL.Schema do
  @moduledoc """
  Root GraphQL schema for the API.
  """
  use Absinthe.Schema

  alias VereisWeb.GraphQL.Resolvers

  query do
    @desc "Is the API process running?"
    field :liveness, non_null(:boolean) do
      resolve(&Resolvers.Health.liveness/3)
    end

    @desc "Can the API serve traffic?"
    field :readiness, non_null(:boolean) do
      resolve(&Resolvers.Health.readiness/3)
    end
  end
end
