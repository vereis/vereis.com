defmodule Vereis.Factory do
  @moduledoc "ExMachina factory for generating test data."

  use ExMachina.Ecto, repo: Vereis.Repo

  alias Vereis.Assets.Asset
  alias Vereis.Entries.Entry
  alias Vereis.Entries.Reference
  alias Vereis.Repo

  @fixtures_path Path.join([File.cwd!(), "test/support/fixtures"])

  def entry_factory do
    %Entry{
      slug: sequence(:slug, &"entry-#{&1}"),
      title: sequence(:title, &"Entry #{&1}"),
      type: :entry,
      body: "<p>Test body content</p>",
      raw_body: "Test body content",
      description: "Test description"
    }
  end

  def stub_factory do
    %Entry{
      slug: sequence(:slug, &"stub-#{&1}"),
      title: sequence(:title, &"Stub #{&1}"),
      type: :stub
    }
  end

  def reference_factory do
    %Reference{
      source_slug: sequence(:source_slug, &"source-#{&1}"),
      target_slug: sequence(:target_slug, &"target-#{&1}"),
      type: :inline
    }
  end

  def asset_factory do
    %Asset{
      slug: sequence(:slug, &"assets/image-#{&1}.webp"),
      content_type: "image/webp",
      data: File.read!(Path.join(@fixtures_path, "tiny_1x1.png")),
      source_hash: sequence(:source_hash, &"hash#{&1}")
    }
  end

  def image_asset_factory do
    %Asset{
      slug: sequence(:slug, &"assets/image-#{&1}.webp"),
      content_type: "image/webp",
      data: File.read!(Path.join(@fixtures_path, "tiny_1x1.png")),
      source_hash: sequence(:source_hash, &"hash#{&1}"),
      metadata: %Vereis.Assets.Metadata.Image{
        width: 1,
        height: 1,
        lqip_hash: 0
      }
    }
  end

  # HACK: ExMachina's insert/2 uses Ecto.Changeset.cast/4, which conflicts with
  #       PolymorphicEmbed (requires cast_polymorphic_embed/2 instead).
  #       See: https://github.com/mathieuprog/polymorphic_embed/issues/57
  #
  #       We override insert/1 and insert/2 to use build + Repo.insert! for
  #       affected factories. This also fixes insert_list since it calls insert
  #       internally.
  defoverridable insert: 1, insert: 2

  def insert(type) when type in [:image_asset] do
    insert(type, [])
  end

  def insert(type) do
    super(type)
  end

  def insert(type, attrs) when type in [:image_asset] do
    type
    |> build(attrs)
    |> Repo.insert!()
  end

  def insert(type, attrs) do
    super(type, attrs)
  end
end
