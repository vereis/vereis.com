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

    @desc "Fetch a single entry by slug"
    field :entry, :entry do
      arg :slug, non_null(:string)
      resolve(&Resolvers.Entry.entry/3)
    end

    @desc "List all entries with cursor-based pagination"
    connection field :entries, node_type: :entry do
      arg :order_by, list_of(:entry_order_by), description: "Sort entries by multiple fields"
      arg :search, :string, description: "Search entries by title or content"
      arg :is_published, :boolean, description: "Filter by published status"
      arg :type, :entry_type, description: "Filter by entry type (entry or stub)"

      resolve(&Resolvers.Entry.entries/2)
    end
  end
end
