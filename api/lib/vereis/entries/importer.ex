defmodule Vereis.Entries.Importer do
  @moduledoc "Handles bulk import of entries from markdown files."

  alias Vereis.Entries.Entry
  alias Vereis.Entries.Heading
  alias Vereis.Entries.Parser
  alias Vereis.Entries.Reference
  alias Vereis.Repo

  require Logger

  @spec import_entries(String.t()) :: {:ok, map()} | {:error, term()}
  def import_entries(dir) when is_binary(dir) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    with {:ok, parse_result} <- Parser.parse(dir) do
      {parsed, parse_errors} = Enum.split_with(parse_result, &match?({:ok, _}, &1))

      if parse_errors != [] do
        Logger.warning("Parse errors during import: #{inspect(Enum.take(parse_errors, 5))}")
      end

      entries = Enum.map(parsed, fn {:ok, {entry_attrs, _ref_attrs}} -> entry_attrs end)
      refs = Enum.flat_map(parsed, fn {:ok, {_entry_attrs, ref_attrs}} -> ref_attrs end)

      Repo.transaction(fn ->
        # HACK: Build a list of attrs for both real entries and stubs
        #  - If an entry references an entry that doesn't exist we create a stub entry for it.
        #  - If an entry shares a slug with a stub, the real entry will overwrite the stub.
        entry_attrs =
          entries
          |> build_entry_attrs(now)
          |> Enum.concat(build_stub_attrs(refs, now))
          |> Enum.uniq_by(& &1.slug)

        ref_attrs = build_ref_attrs(refs, now)

        {entry_count, _inserted_entries} =
          Repo.insert_all(
            Entry,
            entry_attrs,
            on_conflict: {:replace_all_except, [:id, :inserted_at]},
            conflict_target: [:slug],
            placeholders: %{now: now}
          )

        imported_slugs = Enum.map(entries, & &1.slug)

        {_deleted_ref_count, _deleted_refs} =
          [source_slug: imported_slugs]
          |> Reference.query()
          |> Repo.delete_all()

        {ref_count, _inserted_refs} =
          Repo.insert_all(Reference, ref_attrs,
            on_conflict: :nothing,
            conflict_target: [:source_slug, :target_slug, :type],
            placeholders: %{now: now}
          )

        Logger.info("Imported #{entry_count} entries, #{ref_count} references")

        %{entries_count: entry_count, references_count: ref_count}
      end)
    end
  end

  defp build_stub_attrs(refs, _now) do
    refs
    |> Enum.map(& &1.target_slug)
    |> Enum.uniq()
    |> Enum.map(fn slug ->
      %{
        slug: slug,
        title: Entry.derive_title(slug),
        type: :stub,
        body: nil,
        raw_body: nil,
        description: nil,
        source_hash: :sha256 |> :crypto.hash(slug) |> Base.encode16(case: :lower),
        headings: [],
        inserted_at: {:placeholder, :now},
        updated_at: {:placeholder, :now}
      }
    end)
  end

  defp build_entry_attrs(entries, _now) do
    Enum.map(entries, fn entry ->
      headings =
        entry
        |> Map.get(:headings, [])
        |> Enum.map(&struct!(Heading, &1))

      %{
        slug: entry.slug,
        title: entry.title,
        body: Map.get(entry, :body, ""),
        raw_body: Map.get(entry, :raw_body, ""),
        description: Map.get(entry, :description, ""),
        source_hash: entry.source_hash,
        headings: headings,
        type: :entry,
        inserted_at: {:placeholder, :now},
        updated_at: {:placeholder, :now}
      }
    end)
  end

  defp build_ref_attrs(refs, _now) do
    Enum.map(refs, &Map.put(&1, :inserted_at, {:placeholder, :now}))
  end
end
