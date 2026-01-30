defmodule Vereis.Assets.ParserTest do
  use ExUnit.Case, async: true

  alias Vereis.Assets.Parser

  @fixtures_path Path.join([File.cwd!(), "test/support/fixtures"])

  setup do
    {:ok, temp_dir} = Briefly.create(type: :directory)
    %{temp_dir: temp_dir}
  end

  describe "parse/1 (directory)" do
    test "parses all supported images in directory", %{temp_dir: temp_dir} do
      tiny_png = File.read!(Path.join(@fixtures_path, "tiny_1x1.png"))
      File.write!(Path.join(temp_dir, "test.png"), tiny_png)
      File.write!(Path.join(temp_dir, "test2.jpg"), tiny_png)

      assert {:ok, results} = Parser.parse(temp_dir)
      assert length(results) == 2

      slugs = Enum.map(results, fn {:ok, attrs} -> attrs.slug end)
      assert "test.webp" in slugs
      assert "test2.webp" in slugs
    end

    test "parses nested directories", %{temp_dir: temp_dir} do
      tiny_png = File.read!(Path.join(@fixtures_path, "tiny_1x1.png"))
      nested = Path.join(temp_dir, "images/photos")
      File.mkdir_p!(nested)
      File.write!(Path.join(nested, "photo.png"), tiny_png)

      assert {:ok, results} = Parser.parse(temp_dir)
      assert length(results) == 1
      assert {:ok, attrs} = hd(results)
      assert attrs.slug == "images/photos/photo.webp"
    end

    test "returns error for invalid directory" do
      assert {:error, {:invalid_directory, _}} = Parser.parse("/nonexistent/path")
    end
  end

  describe "parse/2 (filepath, base_dir)" do
    test "reads file and delegates to parse/3", %{temp_dir: temp_dir} do
      tiny_png = File.read!(Path.join(@fixtures_path, "tiny_1x1.png"))
      path = Path.join(temp_dir, "test.png")
      File.write!(path, tiny_png)

      assert {:ok, attrs} = Parser.parse(path, temp_dir)
      assert attrs.slug == "test.webp"
    end
  end

  describe "parse/3 (filepath, data, base_dir)" do
    test "parses image and extracts metadata", %{temp_dir: temp_dir} do
      fixture_path = Path.join(@fixtures_path, "test_image.jpg")
      data = File.read!(fixture_path)
      path = Path.join(temp_dir, "test.jpg")
      File.write!(path, data)

      assert {:ok, attrs} = Parser.parse(path, data, temp_dir)

      assert attrs.slug == "test.webp"
      assert attrs.content_type == "image/webp"
      assert is_binary(attrs.data)
      assert is_binary(attrs.source_hash)
      assert attrs.metadata.__type__ == "image"
      assert attrs.metadata.width == 1479
      assert attrs.metadata.height == 766
    end

    test "derives slug from filepath relative to base_dir", %{temp_dir: temp_dir} do
      tiny_png = File.read!(Path.join(@fixtures_path, "tiny_1x1.png"))
      nested = Path.join(temp_dir, "blog/post")
      File.mkdir_p!(nested)
      path = Path.join(nested, "diagram.png")
      File.write!(path, tiny_png)

      assert {:ok, attrs} = Parser.parse(path, tiny_png, temp_dir)
      assert attrs.slug == "blog/post/diagram.webp"
    end

    test "generates consistent source_hash for same content", %{temp_dir: temp_dir} do
      tiny_png = File.read!(Path.join(@fixtures_path, "tiny_1x1.png"))
      path1 = Path.join(temp_dir, "a.png")
      path2 = Path.join(temp_dir, "b.png")
      File.write!(path1, tiny_png)
      File.write!(path2, tiny_png)

      assert {:ok, attrs1} = Parser.parse(path1, tiny_png, temp_dir)
      assert {:ok, attrs2} = Parser.parse(path2, tiny_png, temp_dir)
      assert attrs1.source_hash == attrs2.source_hash
    end

    test "returns error for unsupported content type", %{temp_dir: temp_dir} do
      path = Path.join(temp_dir, "test.txt")
      File.write!(path, "hello")

      assert {:error, {:unsupported_type, _, _}} = Parser.parse(path, "hello", temp_dir)
    end

    test "generates LQIP hash of 0 for tiny images", %{temp_dir: temp_dir} do
      tiny_png = File.read!(Path.join(@fixtures_path, "tiny_1x1.png"))
      path = Path.join(temp_dir, "test.png")
      File.write!(path, tiny_png)

      assert {:ok, attrs} = Parser.parse(path, tiny_png, temp_dir)
      assert attrs.metadata.lqip_hash == 0
    end

    test "generates non-zero LQIP hash for normal images", %{temp_dir: temp_dir} do
      fixture_path = Path.join(@fixtures_path, "test_image.jpg")
      data = File.read!(fixture_path)
      path = Path.join(temp_dir, "photo.jpg")
      File.write!(path, data)

      assert {:ok, attrs} = Parser.parse(path, data, temp_dir)
      assert attrs.metadata.lqip_hash != 0
    end
  end
end
