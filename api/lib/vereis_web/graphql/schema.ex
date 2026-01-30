defmodule VereisWeb.GraphQL.Schema do
  @moduledoc """
  Root GraphQL schema for the API.
  """
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  alias VereisWeb.GraphQL.Resolvers

  import_types VereisWeb.GraphQL.Types.Scalars
  import_types VereisWeb.GraphQL.Types.Entry
  import_types VereisWeb.GraphQL.Types.Reference
  import_types VereisWeb.GraphQL.Types.Version

  node interface do
    resolve_type fn
      %Vereis.Entries.Entry{}, _ -> :entry
      %Vereis.Entries.Reference{}, _ -> :reference
      _, _ -> nil
    end
  end

  def context(ctx) do
    loader = Dataloader.add_source(Dataloader.new(), :db, VereisWeb.Dataloader.source())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end

  query do
    node field do
      resolve(&Resolvers.Entry.node/2)
    end

    import_fields :entry_queries

    @desc "Is the API process running?"
    field :liveness, non_null(:boolean) do
      resolve(&Resolvers.Health.liveness/3)
    end

    @desc "Can the API serve traffic?"
    field :readiness, non_null(:boolean) do
      resolve(&Resolvers.Health.readiness/3)
    end

    @desc "API version information"
    field :version, non_null(:version) do
      resolve(fn _parent, _args, _resolution ->
        {:ok, %{}}
      end)
    end
  end
end
