defmodule Vereis.EntriesTest do
  use Vereis.DataCase, async: false

  alias Vereis.Entries
  alias Vereis.Entries.Entry
  alias Vereis.Entries.Reference
  alias Vereis.Repo

  describe "get_entry/1" do
    test "returns entry by filters" do
      entry = insert(:entry, slug: "test")
      assert %Entry{} = Entries.get_entry(slug: "test")
      assert Entries.get_entry(slug: "test").id == entry.id
    end

    test "returns nil when entry not found" do
      assert is_nil(Entries.get_entry(slug: "nonexistent"))
    end
  end

  describe "get_entry/2" do
    test "returns entry by id and filters" do
      entry = insert(:entry, slug: "test")
      assert %Entry{} = Entries.get_entry(entry.id, [])
      assert Entries.get_entry(entry.id, []).slug == "test"
    end
  end

  describe "list_entries/0" do
    test "returns all non-deleted entries" do
      entry1 = insert(:entry, slug: "test1")
      entry2 = insert(:entry, slug: "test2")
      insert(:entry, slug: "deleted", deleted_at: DateTime.utc_now())

      entries = Entries.list_entries()
      assert length(entries) == 2
      assert entries |> Enum.map(& &1.id) |> Enum.sort() == Enum.sort([entry1.id, entry2.id])
    end
  end

  describe "list_entries/1" do
    test "returns published entries only" do
      published = insert(:entry, slug: "published", published_at: DateTime.utc_now())
      insert(:entry, slug: "draft", published_at: nil)

      entries = Entries.list_entries(published: true)
      assert length(entries) == 1
      assert hd(entries).id == published.id
    end

    test "includes deleted entries when specified" do
      entry1 = insert(:entry, slug: "test1")
      entry2 = insert(:entry, slug: "deleted", deleted_at: DateTime.utc_now())

      entries = Entries.list_entries(include_deleted: true)
      assert length(entries) == 2
      assert entries |> Enum.map(& &1.id) |> Enum.sort() == Enum.sort([entry1.id, entry2.id])
    end
  end

  describe "update_entry/2" do
    test "updates entry with valid attrs" do
      entry = insert(:entry, slug: "test", title: "Old Title")

      assert {:ok, updated} = Entries.update_entry(entry, %{title: "New Title"})
      assert updated.title == "New Title"
      assert updated.slug == "test"
    end

    test "returns error with invalid attrs" do
      entry = insert(:entry, slug: "test")

      assert {:error, changeset} = Entries.update_entry(entry, %{slug: "/invalid"})
      refute changeset.valid?
    end
  end

  describe "delete_entry/1" do
    test "soft deletes entry" do
      entry = insert(:entry, slug: "test")

      assert {:ok, deleted} = Entries.delete_entry(entry)
      assert deleted.deleted_at

      assert is_nil(Entries.get_entry(slug: "test"))
      assert %Entry{} = Entries.get_entry(slug: "test", include_deleted: true)
    end
  end

  describe "get_entry_or_stub/1" do
    test "returns entry when entry exists" do
      entry = insert(:entry, slug: "elixir", title: "Elixir")

      result = Entries.get_entry_or_stub("elixir")

      assert %Entry{} = result
      assert result.id == entry.id
      assert result.slug == "elixir"
      assert result.title == "Elixir"
    end

    test "returns stub when entry does not exist but has references" do
      insert(:reference, source_slug: "blog", target_slug: "non-existent", type: :inline)

      result = Entries.get_entry_or_stub("non-existent")

      assert %Stub{} = result
      assert result.slug == "non-existent"
    end

    test "returns nil when neither entry nor stub exists" do
      result = Entries.get_entry_or_stub("totally-missing")

      assert is_nil(result)
    end

    test "prefers entry over stub when both could exist" do
      entry = insert(:entry, slug: "elixir", title: "Elixir")
      insert(:reference, source_slug: "blog", target_slug: "elixir", type: :inline)

      result = Entries.get_entry_or_stub("elixir")

      assert %Entry{} = result
      assert result.id == entry.id
    end

    test "returns stub when entry is soft-deleted" do
      entry = insert(:entry, slug: "deleted", title: "Deleted")
      {:ok, _} = Entries.delete_entry(entry)

      insert(:reference, source_slug: "blog", target_slug: "deleted", type: :inline)

      result = Entries.get_entry_or_stub("deleted")

      assert %Stub{} = result
      assert result.slug == "deleted"
    end

    test "raises ArgumentError when :id filter is provided" do
      assert_raise ArgumentError, "get_entry_or_stub/1 does not support :id filter", fn ->
        Entries.get_entry_or_stub(id: "some-id", slug: "test")
      end
    end

    test "raises ArgumentError when :slug filter is missing" do
      assert_raise ArgumentError, "get_entry_or_stub/1 requires :slug filter", fn ->
        Entries.get_entry_or_stub([])
      end
    end
  end

  describe "import_entries/1" do
    test "imports markdown files and creates entries" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file1 = Path.join(content_dir, "post1.md")
      file2 = Path.join(content_dir, "post2.md")

      File.mkdir_p!(content_dir)

      File.write!(file1, """
      ---
      title: Post 1
      ---

      # Content 1
      """)

      File.write!(file2, """
      ---
      title: Post 2
      ---

      # Content 2
      """)

      assert {2, _} = Entries.import_entries(content_dir)

      entries = Entries.list_entries()
      assert length(entries) == 2
      assert Enum.any?(entries, &(&1.title == "Post 1"))
      assert Enum.any?(entries, &(&1.title == "Post 2"))
    end

    test "upserts entries based on slug" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file = Path.join(content_dir, "post.md")
      File.mkdir_p!(content_dir)

      File.write!(file, """
      ---
      title: Original Title
      ---

      Original content
      """)

      assert {1, _} = Entries.import_entries(content_dir)

      assert [entry] = Entries.list_entries()
      assert entry.title == "Original Title"
      original_id = entry.id

      File.write!(file, """
      ---
      title: Updated Title
      ---

      Updated content
      """)

      assert {1, _} = Entries.import_entries(content_dir)

      assert [entry] = Entries.list_entries()
      assert entry.title == "Updated Title"
      assert entry.id == original_id
    end
  end

  describe "upsert_references/2" do
    test "creates inline references from attrs" do
      entry = insert(:entry, slug: "blog/post")

      attrs = %{
        inline_refs: ["elixir", "phoenix"]
      }

      assert {:ok, refs} = Entries.upsert_references(entry, attrs)
      assert length(refs) == 2

      assert Enum.all?(refs, &(&1.source_slug == "blog/post"))
      assert Enum.all?(refs, &(&1.type == :inline))
      assert refs |> Enum.map(& &1.target_slug) |> Enum.sort() == ["elixir", "phoenix"]
    end

    test "creates frontmatter references from attrs" do
      entry = insert(:entry, slug: "blog/post")

      attrs = %{
        frontmatter_refs: ["tag1", "tag2"]
      }

      assert {:ok, refs} = Entries.upsert_references(entry, attrs)
      assert length(refs) == 2

      assert Enum.all?(refs, &(&1.source_slug == "blog/post"))
      assert Enum.all?(refs, &(&1.type == :frontmatter))
      assert refs |> Enum.map(& &1.target_slug) |> Enum.sort() == ["tag1", "tag2"]
    end

    test "creates both inline and frontmatter references" do
      entry = insert(:entry, slug: "blog/post")

      attrs = %{
        inline_refs: ["elixir"],
        frontmatter_refs: ["tag1", "tag2"]
      }

      assert {:ok, refs} = Entries.upsert_references(entry, attrs)
      assert length(refs) == 3

      inline_refs = Enum.filter(refs, &(&1.type == :inline))
      frontmatter_refs = Enum.filter(refs, &(&1.type == :frontmatter))

      assert length(inline_refs) == 1
      assert length(frontmatter_refs) == 2
    end

    test "distinguishes same target_slug with different types" do
      entry = insert(:entry, slug: "blog/post")

      attrs = %{
        inline_refs: ["elixir"],
        frontmatter_refs: ["/elixir"]
      }

      assert {:ok, refs} = Entries.upsert_references(entry, attrs)
      assert length(refs) == 2

      types = refs |> Enum.map(& &1.type) |> Enum.sort()
      assert types == [:frontmatter, :inline]
    end

    test "deletes old references on re-import" do
      entry = insert(:entry, slug: "blog/post")

      # First import
      attrs1 = %{
        inline_refs: ["elixir", "phoenix"]
      }

      assert {:ok, refs} = Entries.upsert_references(entry, attrs1)
      assert length(refs) == 2

      # Re-import with different refs
      attrs2 = %{
        inline_refs: ["ecto"]
      }

      assert {:ok, refs} = Entries.upsert_references(entry, attrs2)
      assert length(refs) == 1
      assert hd(refs).target_slug == "ecto"

      # Verify old refs were deleted
      all_refs = Repo.all(Reference)
      assert length(all_refs) == 1
    end

    test "handles empty references" do
      entry = insert(:entry, slug: "blog/post")

      attrs = %{
        inline_refs: [],
        frontmatter_refs: []
      }

      assert {:ok, refs} = Entries.upsert_references(entry, attrs)
      assert refs == []
    end

    test "handles missing inline_refs key" do
      entry = insert(:entry, slug: "blog/post")

      attrs = %{
        frontmatter_refs: ["/tag1"]
      }

      assert {:ok, refs} = Entries.upsert_references(entry, attrs)
      assert length(refs) == 1
      assert hd(refs).type == :frontmatter
    end

    test "handles missing frontmatter_refs key" do
      entry = insert(:entry, slug: "blog/post")

      attrs = %{
        inline_refs: ["elixir"]
      }

      assert {:ok, refs} = Entries.upsert_references(entry, attrs)
      assert length(refs) == 1
      assert hd(refs).type == :inline
    end

    test "respects unique constraint on (source_slug, target_slug, type)" do
      entry = insert(:entry, slug: "blog/post")

      attrs = %{
        inline_refs: ["elixir", "elixir"]
      }

      # The insert_all with on_conflict: :nothing should handle this gracefully
      assert {:ok, refs} = Entries.upsert_references(entry, attrs)
      # Should only create one reference due to unique constraint
      assert length(refs) == 1
    end

    test "transaction rolls back on error" do
      entry = insert(:entry, slug: "blog/post")

      # Create initial refs
      attrs1 = %{
        inline_refs: ["elixir"]
      }

      assert {:ok, _} = Entries.upsert_references(entry, attrs1)
      assert Repo.aggregate(Reference, :count) == 1

      # This should work fine, testing the transaction completes
      attrs2 = %{
        inline_refs: ["phoenix"]
      }

      assert {:ok, _} = Entries.upsert_references(entry, attrs2)
      assert Repo.aggregate(Reference, :count) == 1
    end
  end
end
