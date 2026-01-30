defmodule Vereis.Assets.AssetTest do
  use Vereis.DataCase, async: false

  alias Vereis.Assets.Asset
  alias Vereis.Assets.Metadata

  defp poly_errors_on(changeset) do
    PolymorphicEmbed.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  describe "changeset/2" do
    test "valid asset with image metadata" do
      attrs = %{
        slug: "test/image",
        content_type: "image/webp",
        data: <<0, 1, 2, 3>>,
        source_hash: "abc123",
        metadata: %{
          __type__: "image",
          width: 800,
          height: 600,
          lqip_hash: 12_345
        }
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      assert changeset.valid?
    end

    test "valid asset without metadata" do
      attrs = %{
        slug: "test/image",
        content_type: "image/png",
        data: <<0, 1, 2, 3>>,
        source_hash: "abc123"
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      assert changeset.valid?
    end

    test "requires slug" do
      attrs = %{
        content_type: "image/png",
        data: <<0, 1, 2>>,
        source_hash: "abc123"
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      refute changeset.valid?
      assert %{slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires content_type" do
      attrs = %{
        slug: "test/image",
        data: <<0, 1, 2>>,
        source_hash: "abc123"
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      refute changeset.valid?
      assert %{content_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires data" do
      attrs = %{
        slug: "test/image",
        content_type: "image/png",
        source_hash: "abc123"
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      refute changeset.valid?
      assert %{data: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires source_hash" do
      attrs = %{
        slug: "test/image",
        content_type: "image/png",
        data: <<0, 1, 2>>
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      refute changeset.valid?
      assert %{source_hash: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "metadata - image" do
    test "accepts valid image metadata" do
      attrs = %{
        slug: "test/photo",
        content_type: "image/webp",
        data: <<1, 2, 3>>,
        source_hash: "hash123",
        metadata: %{
          __type__: "image",
          width: 1920,
          height: 1080,
          lqip_hash: -42
        }
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      assert changeset.valid?

      {:ok, asset} = Repo.insert(changeset)
      assert %Metadata.Image{width: 1920, height: 1080, lqip_hash: -42} = asset.metadata
    end

    test "requires width and height" do
      attrs = %{
        slug: "test/photo",
        content_type: "image/webp",
        data: <<1, 2, 3>>,
        source_hash: "hash123",
        metadata: %{
          __type__: "image",
          lqip_hash: 12_345
        }
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      refute changeset.valid?

      assert %{metadata: %{width: ["can't be blank"], height: ["can't be blank"]}} =
               poly_errors_on(changeset)
    end

    test "rejects invalid dimensions" do
      attrs = %{
        slug: "test/photo",
        content_type: "image/webp",
        data: <<1, 2, 3>>,
        source_hash: "hash123",
        metadata: %{
          __type__: "image",
          width: 0,
          height: -1
        }
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      refute changeset.valid?
      assert %{metadata: metadata_errors} = poly_errors_on(changeset)
      assert metadata_errors[:width] || metadata_errors[:height]
    end
  end

  describe "metadata - video" do
    test "returns stub error" do
      attrs = %{
        slug: "test/video",
        content_type: "video/mp4",
        data: <<1, 2, 3>>,
        source_hash: "hash123",
        metadata: %{__type__: "video"}
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      refute changeset.valid?
      assert %{metadata: %{__stub__: _}} = poly_errors_on(changeset)
    end
  end

  describe "metadata - document" do
    test "returns stub error" do
      attrs = %{
        slug: "test/doc",
        content_type: "application/pdf",
        data: <<1, 2, 3>>,
        source_hash: "hash123",
        metadata: %{__type__: "document"}
      }

      changeset = Asset.changeset(%Asset{}, attrs)
      refute changeset.valid?
      assert %{metadata: %{__stub__: _}} = poly_errors_on(changeset)
    end
  end

  describe "database constraints" do
    test "unique constraint on slug" do
      attrs = %{
        slug: "unique-test",
        content_type: "image/png",
        data: <<1, 2, 3>>,
        source_hash: "hash1"
      }

      {:ok, _} = %Asset{} |> Asset.changeset(attrs) |> Repo.insert()

      {:error, changeset} =
        %Asset{}
        |> Asset.changeset(%{attrs | source_hash: "hash2"})
        |> Repo.insert()

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
