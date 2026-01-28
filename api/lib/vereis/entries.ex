defmodule Vereis.Entries do
  @moduledoc "Context module for managing wiki/blog entries."

  import Ecto.Query

  alias Vereis.Entries.Entry
  alias Vereis.Entries.Importer
  alias Vereis.Entries.Reference
  alias Vereis.Repo

  require Logger

  @spec get_entry(keyword()) :: Entry.t() | nil
  def get_entry(filters) when is_list(filters) do
    filters |> Entry.query() |> Repo.one()
  end

  @spec get_entry(any(), keyword()) :: Entry.t() | nil
  def get_entry(id, filters) do
    filters |> Keyword.put(:id, id) |> get_entry()
  end

  @spec list_entries(keyword()) :: [Entry.t()]
  def list_entries(filters \\ []) when is_list(filters) do
    filters |> Entry.query() |> Repo.all()
  end

  @spec update_entry(Entry.t(), map()) :: {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def update_entry(%Entry{} = entry, attrs) do
    entry
    |> Entry.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_entry(Entry.t()) :: {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def delete_entry(%Entry{} = entry) do
    update_entry(entry, %{deleted_at: DateTime.truncate(DateTime.utc_now(), :second)})
  end

  @spec upsert_references(Entry.t(), map()) :: {:ok, [Reference.t()]} | {:error, term()}
  def upsert_references(%Entry{} = entry, attrs) when is_map(attrs) do
    inline_refs = Map.get(attrs, :inline_refs, [])
    frontmatter_refs = Map.get(attrs, :frontmatter_refs, [])

    Repo.transaction(fn ->
      # Delete old references
      Repo.delete_all(from(r in Reference, where: r.source_slug == ^entry.slug))

      # Build new reference attrs
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

      inline_attrs =
        Enum.map(inline_refs, fn target_slug ->
          %{
            source_slug: entry.slug,
            target_slug: target_slug,
            type: :inline,
            inserted_at: now
          }
        end)

      frontmatter_attrs =
        Enum.map(frontmatter_refs, fn target_slug ->
          %{
            source_slug: entry.slug,
            target_slug: target_slug,
            type: :frontmatter,
            inserted_at: now
          }
        end)

      all_attrs = inline_attrs ++ frontmatter_attrs

      if all_attrs != [] do
        Repo.insert_all(Reference, all_attrs,
          on_conflict: :nothing,
          conflict_target: [:source_slug, :target_slug, :type]
        )
      end

      # Return the newly created references
      Repo.all(from(r in Reference, where: r.source_slug == ^entry.slug))
    end)
  end

  @spec import_entries(String.t()) :: {pos_integer(), nil | [Entry.t()]}
  def import_entries(root, opts \\ []) when is_binary(root) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    filepaths = Path.wildcard(Path.join(root, "**/*.md"))

    {valid_changesets, invalid_changesets} =
      filepaths
      |> Task.async_stream(&Parser.parse(&1, root))
      |> Enum.map(fn {:ok, attrs} -> Entry.changeset(%Entry{}, attrs) end)
      |> Enum.split_with(& &1.valid?)

    attrs =
      Enum.map(valid_changesets, fn changeset ->
        entry = Ecto.Changeset.apply_changes(changeset)

        entry
        |> Map.from_struct()
        |> Map.delete(:__meta__)
        |> Map.put(:inserted_at, {:placeholder, :now})
        |> Map.put(:updated_at, {:placeholder, :now})
      end)

    if invalid_changesets != [] do
      sample =
        invalid_changesets
        |> Enum.take(3)
        |> Enum.map(&Ecto.Changeset.traverse_errors(&1, fn {msg, _opts} -> msg end))

      Logger.warning("Invalid changesets during import: #{inspect(sample)}")
    end

    {count, returned} =
      Repo.insert_all(
        Entry,
        attrs,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: :slug,
        placeholders: %{now: now},
        returning: Keyword.get(opts, :returning, false)
      )

    Logger.info("Imported #{count} entries")

    {count, returned}
  end
end
