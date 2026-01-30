defmodule Vereis.Entries.UtilsTest do
  use ExUnit.Case, async: true

  alias Vereis.Entries.Utils

  describe "path_to_slug/2" do
    test "resolves relative path in same directory" do
      assert {:ok, "blog/photo.png"} = Utils.path_to_slug("./photo.png", "blog/my-post")
    end

    test "resolves relative path to parent directory" do
      assert {:ok, "blog/assets/img.jpg"} = Utils.path_to_slug("../assets/img.jpg", "blog/posts/entry")
    end

    test "resolves relative path without dot prefix" do
      assert {:ok, "blog/sibling.md"} = Utils.path_to_slug("sibling.md", "blog/my-post")
    end

    test "resolves absolute path from content root" do
      assert {:ok, "images/hero.png"} = Utils.path_to_slug("/images/hero.png", "blog/my-post")
    end

    test "returns error for http URLs" do
      assert {:error, :external} = Utils.path_to_slug("https://example.com/img.png", "blog/my-post")
    end

    test "returns error for http URLs (no ssl)" do
      assert {:error, :external} = Utils.path_to_slug("http://example.com/img.png", "blog/my-post")
    end

    test "handles deeply nested relative paths" do
      assert {:ok, "a/b/target.md"} = Utils.path_to_slug("../../b/target.md", "a/c/d/source")
    end

    test "normalizes paths that go above root" do
      assert {:ok, "photo.png"} = Utils.path_to_slug("../../photo.png", "blog/entry")
    end
  end

  describe "external_url?/1" do
    test "returns true for https URLs" do
      assert Utils.external_url?("https://example.com/img.png")
    end

    test "returns true for http URLs" do
      assert Utils.external_url?("http://example.com/img.png")
    end

    test "returns false for relative paths" do
      refute Utils.external_url?("./photo.png")
      refute Utils.external_url?("../assets/img.jpg")
      refute Utils.external_url?("photo.png")
    end

    test "returns false for absolute paths" do
      refute Utils.external_url?("/images/hero.png")
    end
  end

  describe "swap_ext/3" do
    test "swaps extension when it matches" do
      assert "photo.webp" = Utils.swap_ext("photo.png", ".webp", [".png", ".jpg"])
    end

    test "swaps jpg extension" do
      assert "photo.webp" = Utils.swap_ext("photo.jpg", ".webp", [".png", ".jpg"])
    end

    test "leaves extension unchanged when it doesn't match" do
      assert "photo.svg" = Utils.swap_ext("photo.svg", ".webp", [".png", ".jpg"])
    end

    test "handles paths with directories" do
      assert "blog/assets/photo.webp" = Utils.swap_ext("blog/assets/photo.jpeg", ".webp", [".jpeg"])
    end

    test "handles files without extension" do
      assert "README" = Utils.swap_ext("README", ".md", [".txt"])
    end

    test "swaps any extension when list is empty" do
      assert "photo.webp" = Utils.swap_ext("photo.png", ".webp")
      assert "photo.webp" = Utils.swap_ext("photo.svg", ".webp")
      assert "photo.webp" = Utils.swap_ext("photo.anything", ".webp")
    end
  end

  describe "slugify/1" do
    test "converts text to lowercase" do
      assert "hello-world" = Utils.slugify("Hello World")
    end

    test "replaces spaces with hyphens" do
      assert "hello-world" = Utils.slugify("hello world")
    end

    test "removes special characters" do
      assert "hello-world" = Utils.slugify("Hello, World!")
    end

    test "handles accented characters" do
      assert "cafe" = Utils.slugify("Café")
    end

    test "collapses multiple spaces" do
      assert "hello-world" = Utils.slugify("hello   world")
    end

    test "trims leading and trailing hyphens" do
      assert "hello" = Utils.slugify("  hello  ")
    end

    test "preserves existing hyphens" do
      assert "hello-world" = Utils.slugify("hello-world")
    end
  end
end
