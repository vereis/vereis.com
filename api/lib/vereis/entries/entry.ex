defmodule Vereis.Entries.Entry do
  @moduledoc "Schema for wiki/blog entries."

  use Ecto.Schema
  use Vereis.Queryable

  import Ecto.Changeset

  alias Vereis.Entries.Heading
  alias Vereis.Entries.Reference

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "entries" do
    field :slug, :string
    field :title, :string
    field :body, :string
    field :raw_body, :string
    field :description, :string
    field :published_at, :utc_datetime
    field :source_hash, :string
    field :deleted_at, :utc_datetime
    field :type, Ecto.Enum, values: [:entry, :stub], default: :entry

    embeds_many :headings, Heading

    has_many :references, Reference,
      foreign_key: :source_slug,
      references: :slug

    has_many :referenced_by, Reference,
      foreign_key: :target_slug,
      references: :slug

    timestamps()
  end

  @spec changeset(t() | Ecto.Changeset.t(t()), map()) :: Ecto.Changeset.t(t())
  def changeset(entry, attrs) do
    fields = __schema__(:fields) -- [:headings]

    entry
    |> cast(attrs, fields)
    |> coerce_published_at()
    |> cast_embed(:headings, with: &Heading.changeset/2)
    |> validate_required([:slug, :title])
    |> validate_slug()
    |> unique_constraint(:slug)
  end

  defp coerce_published_at(%{changes: %{published_at: value}} = changeset) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        put_change(changeset, :published_at, datetime)

      {:error, _} ->
        add_error(changeset, :published_at, "must be a valid ISO 8601 datetime")
    end
  end

  defp coerce_published_at(changeset) do
    changeset
  end

  defp validate_slug(changeset) do
    slug = get_field(changeset, :slug)

    cond do
      is_nil(slug) ->
        changeset

      slug == "" ->
        add_error(changeset, :slug, "can't be blank")

      String.starts_with?(slug, "/") ->
        add_error(changeset, :slug, "must not start with /")

      String.ends_with?(slug, "/") ->
        add_error(changeset, :slug, "must not end with /")

      not String.match?(slug, ~r/^[a-z0-9_\/-]+$/) ->
        add_error(changeset, :slug, "must be lowercase alphanumeric with hyphens, underscores, or slashes")

      true ->
        changeset
    end
  end

  @doc "Derives a human-readable title from a slug (for stub entries)."
  @spec derive_title(String.t()) :: String.t()
  def derive_title(slug) when is_binary(slug) do
    slug
    |> String.split("/")
    |> Enum.map_join(" / ", &title_case_segment/1)
  end

  defp title_case_segment(segment) do
    segment
    |> String.replace(~r/[-_]/, " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @impl Vereis.Queryable
  def base_query do
    from e in __MODULE__,
      as: :self,
      where: is_nil(e.deleted_at)
  end

  @impl Vereis.Queryable
  def query(base_query \\ base_query(), filters) do
    {include_deleted, filters} = Keyword.pop(filters, :include_deleted)
    base_query = (include_deleted && from(e in __MODULE__, as: :self)) || base_query

    Enum.reduce(filters, base_query, fn
      {:published, true}, query ->
        from e in query,
          where: not is_nil(e.published_at),
          order_by: [desc: e.published_at]

      {:is_published, true}, query ->
        from e in query, where: not is_nil(e.published_at)

      {:is_published, false}, query ->
        from e in query, where: is_nil(e.published_at)

      {:search, term}, query when is_binary(term) and term != "" ->
        # TODO: migrate to SQLite FTS5 for better search features
        search_pattern = "%#{String.downcase(term)}%"

        from e in query,
          where:
            "LOWER(?)" |> fragment(e.title) |> like(^search_pattern) or
              "LOWER(?)" |> fragment(e.raw_body) |> like(^search_pattern)

      {:prefix, prefix}, query when is_binary(prefix) ->
        pattern = "#{prefix}%"
        from e in query, where: like(e.slug, ^pattern)

      {key, value}, query ->
        apply_filter(query, {key, value})
    end)
  end
end
