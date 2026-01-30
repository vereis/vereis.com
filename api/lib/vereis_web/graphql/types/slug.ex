defmodule VereisWeb.GraphQL.Types.Slug do
  @moduledoc "Slug GraphQL type and queries."

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias VereisWeb.GraphQL.Resolvers.Slug, as: SlugResolver

  @desc "A slug (current entry slug or permalink)"
  node object(:slug) do
    @desc "The slug value"
    field :slug, non_null(:string)

    @desc "When this slug was soft-deleted"
    field :deleted_at, :datetime

    @desc "When this slug was created"
    field :inserted_at, non_null(:datetime)

    @desc "The entry this slug points to"
    field :entry, non_null(:entry), resolve: dataloader(:db)
  end

  @desc "Paginated slugs"
  connection(node_type: :slug)

  object :slug_queries do
    @desc "Get a specific slug"
    field :slug, :slug do
      arg :slug, non_null(:string)
      resolve &SlugResolver.slug/3
    end

    @desc "List all slugs"
    connection field :slugs, node_type: :slug do
      arg :include_deleted, :boolean, default_value: false, description: "Include soft-deleted slugs"

      resolve &SlugResolver.slugs/3
    end
  end
end
