defmodule VereisWeb.GraphQL.Schema do
  @moduledoc """
  Root GraphQL schema for the API.
  """
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  alias VereisWeb.GraphQL.Resolvers

  import_types VereisWeb.GraphQL.Types.Asset
  import_types VereisWeb.GraphQL.Types.Entry
  import_types VereisWeb.GraphQL.Types.Reference
  import_types VereisWeb.GraphQL.Types.Scalars
  import_types VereisWeb.GraphQL.Types.Service
  import_types VereisWeb.GraphQL.Types.Slug

  node interface do
    resolve_type fn
      %Vereis.Assets.Asset{}, _ -> :asset
      %Vereis.Entries.Entry{}, _ -> :entry
      %Vereis.Entries.Reference{}, _ -> :reference
      %Vereis.Entries.Slug{}, _ -> :slug
      %Vereis.Service{}, _ -> :service
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

    import_fields :asset_queries
    import_fields :entry_queries
    import_fields :slug_queries

    @desc "The running API service instance"
    field :service, non_null(:service) do
      resolve(&Resolvers.Service.get/3)
    end
  end
end
