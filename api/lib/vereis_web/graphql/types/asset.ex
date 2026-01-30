defmodule VereisWeb.GraphQL.Types.Asset do
  @moduledoc "Asset (image, etc.) GraphQL type."

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias VereisWeb.GraphQL.Resolvers.Asset, as: AssetResolver

  @desc "Image-specific metadata"
  object :image_metadata do
    @desc "Image width in pixels"
    field :width, non_null(:integer)

    @desc "Image height in pixels"
    field :height, non_null(:integer)

    @desc "20-bit OKLab LQIP hash (0 for images smaller than 3x2)"
    field :lqip_hash, non_null(:integer)
  end

  @desc "Video-specific metadata (stub)"
  object :video_metadata do
    @desc "Video width in pixels"
    field :width, :integer

    @desc "Video height in pixels"
    field :height, :integer

    @desc "Video duration in seconds"
    field :duration, :float
  end

  @desc "Document-specific metadata (stub)"
  object :document_metadata do
    @desc "Number of pages"
    field :page_count, :integer
  end

  @desc "Polymorphic asset metadata"
  union :asset_metadata do
    types [:image_metadata, :video_metadata, :document_metadata]

    resolve_type fn
      %Vereis.Assets.Metadata.Image{}, _ -> :image_metadata
      %Vereis.Assets.Metadata.Video{}, _ -> :video_metadata
      %Vereis.Assets.Metadata.Document{}, _ -> :document_metadata
      _, _ -> nil
    end
  end

  @desc "A binary asset (image, etc.)"
  node object(:asset) do
    @desc "URL slug (path)"
    field :slug, non_null(:string)

    @desc "MIME content type"
    field :content_type, non_null(:string)

    @desc "HTTP URL to fetch the binary asset"
    field :url, non_null(:string) do
      resolve fn asset, _, _ ->
        {:ok, "/assets/#{asset.slug}"}
      end
    end

    @desc "Type-specific metadata (use fragments to access fields)"
    field :metadata, :asset_metadata

    @desc "When the asset was created"
    field :inserted_at, non_null(:datetime)

    @desc "When the asset was last updated"
    field :updated_at, non_null(:datetime)
  end

  @desc "Paginated assets"
  connection(node_type: :asset)

  @desc "Ordering options for assets"
  input_object :asset_order_by do
    field :slug, :order_direction
    field :content_type, :order_direction
    field :inserted_at, :order_direction
    field :updated_at, :order_direction
  end

  object :asset_queries do
    @desc "Fetch a single asset by slug"
    field :asset, :asset do
      arg :slug, non_null(:string)
      resolve &AssetResolver.asset/3
    end

    @desc "List all assets with cursor-based pagination"
    connection field :assets, node_type: :asset do
      arg :order_by, list_of(:asset_order_by), description: "Sort assets by multiple fields"
      arg :content_type_prefix, :string, description: "Filter by content type prefix (e.g., 'image/')"

      resolve &AssetResolver.assets/2
    end
  end
end
