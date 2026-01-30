defmodule Vereis.AssetsTest do
  use Vereis.DataCase, async: false

  import Vereis.Factory

  alias Vereis.Assets

  describe "get_asset/1" do
    test "returns asset by slug" do
      asset = insert(:image_asset, slug: "test/image")

      found = Assets.get_asset(slug: "test/image")
      assert found.id == asset.id
    end

    test "returns nil for non-existent slug" do
      assert is_nil(Assets.get_asset(slug: "nonexistent"))
    end

    test "excludes soft-deleted assets" do
      now = DateTime.truncate(DateTime.utc_now(), :second)
      insert(:image_asset, slug: "deleted/image", deleted_at: now)

      assert is_nil(Assets.get_asset(slug: "deleted/image"))
    end
  end

  describe "list_assets/1" do
    test "returns all assets" do
      insert_list(3, :image_asset)

      assets = Assets.list_assets()
      assert length(assets) == 3
    end

    test "filters by content_type_prefix" do
      insert(:image_asset, slug: "photo", content_type: "image/webp")
      insert(:image_asset, slug: "doc", content_type: "text/plain", data: "hello", metadata: nil)

      images = Assets.list_assets(content_type_prefix: "image/")
      assert length(images) == 1
      assert hd(images).slug == "photo"
    end
  end

  describe "update_asset/2" do
    test "updates asset attributes" do
      asset = insert(:image_asset)

      assert {:ok, updated} = Assets.update_asset(asset, %{source_hash: "new_hash"})
      assert updated.source_hash == "new_hash"
    end
  end

  describe "delete_asset/1" do
    test "soft-deletes asset" do
      asset = insert(:image_asset, slug: "to-delete")

      assert {:ok, deleted} = Assets.delete_asset(asset)
      assert deleted.deleted_at

      assert is_nil(Assets.get_asset(slug: "to-delete"))
    end
  end

  describe "import_assets/1" do
    @fixtures_path Path.join([File.cwd!(), "test/support/fixtures"])

    setup do
      {:ok, temp_dir} = Briefly.create(type: :directory)
      %{temp_dir: temp_dir}
    end

    test "imports images from directory", %{temp_dir: temp_dir} do
      tiny_png = File.read!(Path.join(@fixtures_path, "tiny_1x1.png"))
      File.write!(Path.join(temp_dir, "photo.png"), tiny_png)

      assert {:ok, %{assets_count: 1}} = Assets.import_assets(temp_dir)

      asset = Assets.get_asset(slug: "photo.webp")
      assert asset
      assert asset.content_type == "image/webp"
      assert asset.metadata.width == 1
      assert asset.metadata.height == 1
    end

    test "imports larger images with proper LQIP", %{temp_dir: temp_dir} do
      large_jpg = File.read!(Path.join(@fixtures_path, "test_image.jpg"))
      File.write!(Path.join(temp_dir, "large.jpg"), large_jpg)

      assert {:ok, %{assets_count: 1}} = Assets.import_assets(temp_dir)

      asset = Assets.get_asset(slug: "large.webp")
      assert asset
      assert asset.metadata.width == 1479
      assert asset.metadata.height == 766
      assert asset.metadata.lqip_hash != 0
    end

    test "imports nested directory structure", %{temp_dir: temp_dir} do
      tiny_png = File.read!(Path.join(@fixtures_path, "tiny_1x1.png"))
      nested = Path.join(temp_dir, "blog/post")
      File.mkdir_p!(nested)
      File.write!(Path.join(nested, "diagram.png"), tiny_png)

      assert {:ok, %{assets_count: 1}} = Assets.import_assets(temp_dir)

      asset = Assets.get_asset(slug: "blog/post/diagram.webp")
      assert asset
    end

    test "updates existing asset on conflict", %{temp_dir: temp_dir} do
      tiny_png = File.read!(Path.join(@fixtures_path, "tiny_1x1.png"))
      File.write!(Path.join(temp_dir, "photo.png"), tiny_png)

      assert {:ok, _} = Assets.import_assets(temp_dir)
      first_asset = Assets.get_asset(slug: "photo.webp")

      assert {:ok, _} = Assets.import_assets(temp_dir)
      second_asset = Assets.get_asset(slug: "photo.webp")

      assert first_asset.id == second_asset.id
    end

    test "returns error for invalid directory" do
      assert {:error, _} = Assets.import_assets("/nonexistent/path")
    end
  end
end
