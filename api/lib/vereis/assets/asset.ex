defmodule Vereis.Assets.Asset do
  @moduledoc "Schema for binary assets (images, videos, documents)."

  use Ecto.Schema
  use Vereis.Queryable

  import Ecto.Changeset
  import PolymorphicEmbed

  alias Vereis.Assets.Metadata

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "assets" do
    field :slug, :string
    field :content_type, :string
    field :data, :binary
    field :source_hash, :string
    field :deleted_at, :utc_datetime

    polymorphic_embeds_one(:metadata,
      types: [
        image: Metadata.Image,
        video: Metadata.Video,
        document: Metadata.Document
      ],
      on_type_not_found: :raise,
      on_replace: :update
    )

    timestamps()
  end

  @spec changeset(t() | Ecto.Changeset.t(t()), map()) :: Ecto.Changeset.t(t())
  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [:slug, :content_type, :data, :source_hash, :deleted_at])
    |> cast_polymorphic_embed(:metadata, required: false)
    |> validate_required([:slug, :content_type, :data, :source_hash])
    |> unique_constraint(:slug)
  end

  @impl Vereis.Queryable
  def base_query do
    from a in __MODULE__,
      as: :self,
      where: is_nil(a.deleted_at)
  end

  @impl Vereis.Queryable
  def query(base_query \\ base_query(), filters) do
    {include_deleted, filters} = Keyword.pop(filters, :include_deleted)
    base_query = (include_deleted && from(a in __MODULE__, as: :self)) || base_query

    Enum.reduce(filters, base_query, fn
      {:content_type_prefix, prefix}, query when is_binary(prefix) ->
        from a in query, where: like(a.content_type, ^"#{prefix}%")

      {key, value}, query ->
        apply_filter(query, {key, value})
    end)
  end
end
