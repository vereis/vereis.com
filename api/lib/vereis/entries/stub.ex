defmodule Vereis.Entries.Stub do
  @moduledoc "Schema for stub pages (referenced but non-existent entries)."

  use Ecto.Schema
  use Vereis.Queryable

  import Ecto.Query

  alias Vereis.Entries.Reference

  @primary_key {:slug, :string, autogenerate: false}
  @foreign_key_type :string

  @type t :: %__MODULE__{}

  schema "stubs" do
    field :id, :binary_id
    field :title, :string
    field :body, :string
    field :raw_body, :string
    field :description, :string
    field :published_at, :utc_datetime
    field :source_hash, :string
    field :deleted_at, :utc_datetime
    field :headings, {:array, :map}
    field :type, Ecto.Enum, values: [:entry, :stub], virtual: true

    has_many :references, Reference,
      foreign_key: :source_slug,
      references: :slug

    has_many :referenced_by, Reference,
      foreign_key: :target_slug,
      references: :slug

    timestamps()
  end

  @spec derive_title(String.t()) :: String.t()
  def derive_title("/"), do: "/"

  def derive_title(slug) when is_binary(slug) do
    slug
    |> String.trim_leading("/")
    |> String.split("/")
    |> Enum.map_join(" / ", &title_case_word/1)
  end

  defp title_case_word(word) do
    word
    |> String.replace(~r/[-_]/, " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @impl Vereis.Queryable
  def base_query do
    # Explicit select required for UNION with Entry (different primary keys)
    from s in __MODULE__,
      as: :self,
      select: %__MODULE__{
        id: s.slug,
        slug: s.slug,
        title: s.title,
        body: s.body,
        raw_body: s.raw_body,
        description: s.description,
        published_at: s.published_at,
        source_hash: s.source_hash,
        deleted_at: s.deleted_at,
        headings: s.headings,
        inserted_at: s.inserted_at,
        updated_at: s.updated_at
      },
      select_merge: %{type: "stub"}
  end

  @impl Vereis.Queryable
  def query(base_query \\ base_query(), filters) do
    Enum.reduce(filters, base_query, fn
      {:prefix, prefix}, query when is_binary(prefix) ->
        pattern = "#{prefix}%"
        from s in query, where: like(s.slug, ^pattern)

      filter, query ->
        apply_filter(query, filter)
    end)
  end
end
