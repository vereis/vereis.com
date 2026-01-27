defmodule Vereis.EntriesTest do
  use Vereis.DataCase, async: true

  alias Vereis.Entries
  alias Vereis.Entries.Entry

  describe "get_entry/1" do
    test "returns entry by filters" do
      entry = insert(:entry, slug: "/test")
      assert %Entry{} = Entries.get_entry(slug: "/test")
      assert Entries.get_entry(slug: "/test").id == entry.id
    end

    test "returns nil when entry not found" do
      assert is_nil(Entries.get_entry(slug: "/nonexistent"))
    end
  end

  describe "get_entry/2" do
    test "returns entry by id and filters" do
      entry = insert(:entry, slug: "/test")
      assert %Entry{} = Entries.get_entry(entry.id, [])
      assert Entries.get_entry(entry.id, []).slug == "/test"
    end
  end

  describe "list_entries/0" do
    test "returns all non-deleted entries" do
      entry1 = insert(:entry, slug: "/test1")
      entry2 = insert(:entry, slug: "/test2")
      insert(:entry, slug: "/deleted", deleted_at: DateTime.utc_now())

      entries = Entries.list_entries()
      assert length(entries) == 2
      assert entries |> Enum.map(& &1.id) |> Enum.sort() == Enum.sort([entry1.id, entry2.id])
    end
  end

  describe "list_entries/1" do
    test "returns published entries only" do
      published = insert(:entry, slug: "/published", published_at: DateTime.utc_now())
      insert(:entry, slug: "/draft", published_at: nil)

      entries = Entries.list_entries(published: true)
      assert length(entries) == 1
      assert hd(entries).id == published.id
    end

    test "includes deleted entries when specified" do
      entry1 = insert(:entry, slug: "/test1")
      entry2 = insert(:entry, slug: "/deleted", deleted_at: DateTime.utc_now())

      entries = Entries.list_entries(include_deleted: true)
      assert length(entries) == 2
      assert entries |> Enum.map(& &1.id) |> Enum.sort() == Enum.sort([entry1.id, entry2.id])
    end
  end

  describe "update_entry/2" do
    test "updates entry with valid attrs" do
      entry = insert(:entry, slug: "/test", title: "Old Title")

      assert {:ok, updated} = Entries.update_entry(entry, %{title: "New Title"})
      assert updated.title == "New Title"
      assert updated.slug == "/test"
    end

    test "returns error with invalid attrs" do
      entry = insert(:entry, slug: "/test")

      assert {:error, changeset} = Entries.update_entry(entry, %{slug: "invalid"})
      refute changeset.valid?
    end
  end

  describe "delete_entry/1" do
    test "soft deletes entry" do
      entry = insert(:entry, slug: "/test")

      assert {:ok, deleted} = Entries.delete_entry(entry)
      assert deleted.deleted_at

      assert is_nil(Entries.get_entry(slug: "/test"))
      assert %Entry{} = Entries.get_entry(slug: "/test", include_deleted: true)
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
end
