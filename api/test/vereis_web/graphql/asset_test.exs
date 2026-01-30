defmodule VereisWeb.GraphQL.AssetTest do
  use VereisWeb.ConnCase, async: false

  alias Vereis.Assets.Metadata.Image

  @asset_query """
  query Asset($slug: String!) {
    asset(slug: $slug) {
      id
      slug
      contentType
      url
      metadata {
        ... on ImageMetadata {
          width
          height
          lqipHash
        }
      }
    }
  }
  """

  @assets_query """
  query Assets($first: Int, $contentTypePrefix: String) {
    assets(first: $first, contentTypePrefix: $contentTypePrefix) {
      edges {
        node {
          slug
          contentType
          url
        }
      }
      pageInfo {
        hasNextPage
        hasPreviousPage
      }
    }
  }
  """

  describe "asset query" do
    test "returns asset by slug with image metadata", %{conn: conn} do
      insert(:image_asset,
        slug: "blog/photo.webp",
        content_type: "image/webp",
        metadata: %Image{width: 800, height: 600, lqip_hash: 42}
      )

      conn =
        post(conn, "/graphql", %{
          "query" => @asset_query,
          "variables" => %{"slug" => "blog/photo.webp"}
        })

      assert %{
               "data" => %{
                 "asset" => %{
                   "slug" => "blog/photo.webp",
                   "contentType" => "image/webp",
                   "url" => "/assets/blog/photo.webp",
                   "metadata" => %{
                     "width" => 800,
                     "height" => 600,
                     "lqipHash" => 42
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns null metadata for asset without metadata", %{conn: conn} do
      insert(:asset, slug: "doc.pdf", content_type: "application/pdf")

      conn =
        post(conn, "/graphql", %{
          "query" => @asset_query,
          "variables" => %{"slug" => "doc.pdf"}
        })

      assert %{
               "data" => %{
                 "asset" => %{
                   "slug" => "doc.pdf",
                   "metadata" => nil
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns null for non-existent asset", %{conn: conn} do
      conn =
        post(conn, "/graphql", %{
          "query" => @asset_query,
          "variables" => %{"slug" => "nonexistent.webp"}
        })

      assert %{"data" => %{"asset" => nil}, "errors" => [_]} = json_response(conn, 200)
    end

    test "excludes soft-deleted assets", %{conn: conn} do
      now = DateTime.truncate(DateTime.utc_now(), :second)
      insert(:image_asset, slug: "deleted.webp", deleted_at: now)

      conn =
        post(conn, "/graphql", %{
          "query" => @asset_query,
          "variables" => %{"slug" => "deleted.webp"}
        })

      assert %{"data" => %{"asset" => nil}} = json_response(conn, 200)
    end
  end

  describe "assets connection" do
    test "returns paginated assets", %{conn: conn} do
      insert(:image_asset, slug: "a.webp")
      insert(:image_asset, slug: "b.webp")
      insert(:image_asset, slug: "c.webp")

      conn =
        post(conn, "/graphql", %{
          "query" => @assets_query,
          "variables" => %{"first" => 2}
        })

      response = json_response(conn, 200)

      assert %{
               "data" => %{
                 "assets" => %{
                   "edges" => edges,
                   "pageInfo" => %{"hasNextPage" => true}
                 }
               }
             } = response

      assert length(edges) == 2
    end

    test "filters by content_type_prefix", %{conn: conn} do
      insert(:image_asset, slug: "photo.webp", content_type: "image/webp")
      insert(:asset, slug: "doc.pdf", content_type: "application/pdf")

      conn =
        post(conn, "/graphql", %{
          "query" => @assets_query,
          "variables" => %{"first" => 10, "contentTypePrefix" => "image/"}
        })

      response = json_response(conn, 200)
      edges = get_in(response, ["data", "assets", "edges"])

      assert length(edges) == 1
      assert hd(edges)["node"]["slug"] == "photo.webp"
    end
  end
end
