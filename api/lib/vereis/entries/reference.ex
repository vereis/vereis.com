defmodule Vereis.Entries.Reference do
  @moduledoc "Schema for wiki-link references between entries."

  use Ecto.Schema
  use Vereis.Queryable

  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string

  @type t :: %__MODULE__{}
  @type reference_type :: :inline | :frontmatter

  schema "references" do
    field :type, Ecto.Enum, values: [:inline, :frontmatter]

    belongs_to :source, Entry, foreign_key: :source_slug, references: :slug
    belongs_to :target, Entry, foreign_key: :target_slug, references: :slug

    timestamps(updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(t()), map()) :: Ecto.Changeset.t(t())
  def changeset(reference, attrs) do
    reference
    |> cast(attrs, [:source_slug, :target_slug, :type])
    |> validate_required([:source_slug, :target_slug, :type])
    |> validate_slug(:source_slug)
    |> validate_slug(:target_slug)
    |> unique_constraint([:source_slug, :target_slug, :type])
    |> assoc_constraint(:source)
    |> assoc_constraint(:target)
  end

  defp validate_slug(changeset, field) do
    slug = get_field(changeset, field)

    cond do
      is_nil(slug) ->
        changeset

      slug == "/" ->
        changeset

      not String.starts_with?(slug, "/") ->
        add_error(changeset, field, "must start with /")

      String.ends_with?(slug, "/") ->
        add_error(changeset, field, "must not end with /")

      not String.match?(slug, ~r/^\/[a-z0-9_\/-]+$/) ->
        add_error(
          changeset,
          field,
          "must be lowercase alphanumeric with hyphens, underscores, or slashes"
        )

      true ->
        changeset
    end
  end

  @impl Vereis.Queryable
  def base_query do
    from r in __MODULE__, as: :self
  end

  @impl Vereis.Queryable
  def query(base_query \\ base_query(), filters) do
    Enum.reduce(filters, base_query, fn
      {:target, :entry}, query ->
        from r in query,
          where:
            exists(
              from e in "entries",
                where: e.slug == parent_as(:self).target_slug and is_nil(e.deleted_at),
                select: 1
            )

      {:target, :stub}, query ->
        from r in query,
          where:
            not exists(
              from e in "entries",
                where: e.slug == parent_as(:self).target_slug and is_nil(e.deleted_at),
                select: 1
            )

      filter, query ->
        apply_filter(query, filter)
    end)
  end
end
