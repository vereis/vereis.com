defmodule VereisWeb.AssetControllerTest do
  use VereisWeb.ConnCase, async: false

  alias Vereis.Assets.Metadata.Image

  describe "GET /assets/*slug" do
    test "returns binary asset data with correct content type", %{conn: conn} do
      asset = insert(:image_asset, slug: "test/photo.webp")

      conn = get(conn, "/assets/test/photo.webp")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/webp; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
      assert conn.resp_body == asset.data
    end

    test "returns 404 for non-existent asset", %{conn: conn} do
      conn = get(conn, "/assets/nonexistent/image.webp")

      assert conn.status == 404
      assert json_response(conn, 404) == %{"error" => "Asset not found"}
    end

    test "excludes soft-deleted assets", %{conn: conn} do
      now = DateTime.truncate(DateTime.utc_now(), :second)
      insert(:image_asset, slug: "deleted/photo.webp", deleted_at: now)

      conn = get(conn, "/assets/deleted/photo.webp")

      assert conn.status == 404
    end
  end

  describe "GET /assets/*slug?lqip=true" do
    test "returns HTML preview for image asset", %{conn: conn} do
      insert(:image_asset,
        slug: "test/photo.webp",
        metadata: %Image{width: 800, height: 600, lqip_hash: 42}
      )

      conn = get(conn, "/assets/test/photo.webp?lqip=true")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
      assert conn.resp_body =~ "--lqip:42"
    end

    test "returns error for non-image asset", %{conn: conn} do
      insert(:asset, slug: "test/document.pdf", content_type: "application/pdf")

      conn = get(conn, "/assets/test/document.pdf?lqip=true")

      assert conn.status == 400
      assert json_response(conn, 400) == %{"error" => "LQIP preview only available for image assets"}
    end
  end

  describe "GET /assets/*slug?info=true" do
    test "returns metadata as JSON for image asset", %{conn: conn} do
      insert(:image_asset,
        slug: "test/photo.webp",
        content_type: "image/webp",
        metadata: %Image{width: 100, height: 50, lqip_hash: 12_345}
      )

      conn = get(conn, "/assets/test/photo.webp?info=true")

      assert json_response(conn, 200) == %{
               "slug" => "test/photo.webp",
               "content_type" => "image/webp",
               "width" => 100,
               "height" => 50,
               "lqip_hash" => 12_345
             }
    end

    test "returns metadata without image fields for non-image asset", %{conn: conn} do
      insert(:asset, slug: "test/document.pdf", content_type: "application/pdf")

      conn = get(conn, "/assets/test/document.pdf?info=true")

      assert json_response(conn, 200) == %{
               "slug" => "test/document.pdf",
               "content_type" => "application/pdf"
             }
    end
  end
end
