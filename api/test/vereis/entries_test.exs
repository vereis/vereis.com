defmodule Vereis.EntriesTest do
  use Vereis.DataCase, async: false

  alias Vereis.Entries
  alias Vereis.Entries.Entry
  alias Vereis.Entries.Reference
  alias Vereis.Entries.Slug
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

    test "returns entry by permalink" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file = Path.join(content_dir, "current-post.md")
      File.mkdir_p!(content_dir)

      File.write!(file, """
      ---
      title: Current Post
      permalinks:
        - old-slug
      ---

      Content
      """)

      assert {:ok, _result} = Entries.import_entries(content_dir)

      entry = Entries.get_entry(slug: "current-post")
      assert entry.title == "Current Post"

      same_entry = Entries.get_entry(slug: "old-slug")
      assert same_entry.id == entry.id
      assert same_entry.slug == "current-post"
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

    test "syncs deleted_at to slugs table" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file = Path.join(content_dir, "post.md")
      File.mkdir_p!(content_dir)

      File.write!(file, """
      ---
      title: My Post
      permalinks:
        - old-slug
      ---

      Content
      """)

      assert {:ok, _result} = Entries.import_entries(content_dir)
      entry = Entries.get_entry(slug: "post")

      slugs = Entries.list_slugs(entry_id: entry.id)
      assert length(slugs) == 2
      assert Enum.all?(slugs, &is_nil(&1.deleted_at))

      {:ok, deleted_entry} = Entries.delete_entry(entry)
      assert deleted_entry.deleted_at

      deleted_slugs = Entries.list_slugs(entry_id: entry.id, include_deleted: true)
      assert length(deleted_slugs) == 2
      assert Enum.all?(deleted_slugs, &(&1.deleted_at != nil))
    end
  end

  describe "list_references/1" do
    test "lists all references when no filters provided" do
      insert(:entry, slug: "foo")
      insert(:entry, slug: "bar")
      insert(:entry, slug: "baz")
      insert(:entry, slug: "qux")
      insert(:reference, source_slug: "foo", target_slug: "bar", type: :inline)
      insert(:reference, source_slug: "baz", target_slug: "qux", type: :inline)

      refs = Entries.list_references([])
      assert length(refs) == 2
    end

    test "filters by slug and direction" do
      insert(:entry, slug: "foo")
      insert(:entry, slug: "bar")
      insert(:entry, slug: "baz")
      insert(:reference, source_slug: "foo", target_slug: "bar", type: :inline)
      insert(:reference, source_slug: "baz", target_slug: "foo", type: :inline)

      refs = Entries.list_references(slug: "foo", direction: :outgoing)
      assert length(refs) == 1
      assert hd(refs).source_slug == "foo"
    end

    test "raises ArgumentError when :direction is provided without :slug" do
      assert_raise ArgumentError, "Reference.query/2 requires :slug filter when :direction is specified", fn ->
        Entries.list_references(direction: :incoming)
      end
    end

    test "raises ArgumentError when :slug is provided without :direction" do
      assert_raise ArgumentError, "Reference.query/2 requires :direction filter when :slug is specified", fn ->
        Entries.list_references(slug: "foo")
      end
    end
  end

  describe "list_references/2" do
    test "lists outgoing references for an entry" do
      entry = insert(:entry, slug: "foo")
      insert(:stub, slug: "bar")
      insert(:entry, slug: "baz")
      insert(:reference, source_slug: "foo", target_slug: "bar", type: :inline)
      insert(:reference, source_slug: "baz", target_slug: "foo", type: :inline)

      refs = Entries.list_references(entry)
      assert length(refs) == 1
      assert hd(refs).source_slug == "foo"
    end

    test "lists incoming references for an entry" do
      entry = insert(:entry, slug: "foo")
      insert(:stub, slug: "bar")
      insert(:entry, slug: "baz")
      insert(:reference, source_slug: "foo", target_slug: "bar", type: :inline)
      insert(:reference, source_slug: "baz", target_slug: "foo", type: :inline)

      refs = Entries.list_references(entry, direction: :incoming)
      assert length(refs) == 1
      assert hd(refs).target_slug == "foo"
    end

    test "works with stub entries" do
      stub = insert(:stub, slug: "stub-page")
      insert(:entry, slug: "blog")
      insert(:reference, source_slug: "blog", target_slug: "stub-page", type: :inline)

      refs = Entries.list_references(stub, direction: :incoming)

      assert length(refs) == 1
      assert hd(refs).target_slug == "stub-page"
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

      assert {:ok, result} = Entries.import_entries(content_dir)
      assert result.entries_count == 2
      assert result.references_count >= 0

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

      assert {:ok, result} = Entries.import_entries(content_dir)
      assert result.entries_count == 1

      assert [entry] = Entries.list_entries()
      assert entry.title == "Original Title"
      original_id = entry.id

      File.write!(file, """
      ---
      title: Updated Title
      ---

      Updated content
      """)

      assert {:ok, result} = Entries.import_entries(content_dir)
      assert result.entries_count == 1

      assert [entry] = Entries.list_entries()
      assert entry.title == "Updated Title"
      assert entry.id == original_id
    end

    test "imports entries with inline references" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file = Path.join(content_dir, "post.md")
      File.mkdir_p!(content_dir)

      File.write!(file, """
      ---
      title: My Post
      ---

      Check out [[elixir]] and [[phoenix]]!
      """)

      assert {:ok, result} = Entries.import_entries(content_dir)
      assert result.entries_count == 3
      assert result.references_count == 2

      refs = Repo.all(Reference)
      assert length(refs) == 2
      assert Enum.all?(refs, &(&1.source_slug == "post"))
      assert Enum.all?(refs, &(&1.type == :inline))

      target_slugs = refs |> Enum.map(& &1.target_slug) |> Enum.sort()
      assert target_slugs == ["elixir", "phoenix"]
    end

    test "imports entries with frontmatter references" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file = Path.join(content_dir, "post.md")
      File.mkdir_p!(content_dir)

      File.write!(file, """
      ---
      title: My Post
      references:
        - tag1
        - tag2
      ---

      Content here
      """)

      assert {:ok, result} = Entries.import_entries(content_dir)
      assert result.entries_count == 3
      assert result.references_count == 2

      refs = Repo.all(Reference)
      assert length(refs) == 2
      assert Enum.all?(refs, &(&1.source_slug == "post"))
      assert Enum.all?(refs, &(&1.type == :frontmatter))

      target_slugs = refs |> Enum.map(& &1.target_slug) |> Enum.sort()
      assert target_slugs == ["tag1", "tag2"]
    end

    test "imports entries with both inline and frontmatter references" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file = Path.join(content_dir, "post.md")
      File.mkdir_p!(content_dir)

      File.write!(file, """
      ---
      title: My Post
      references:
        - tag1
      ---

      Check out [[elixir]]!
      """)

      assert {:ok, result} = Entries.import_entries(content_dir)
      assert result.entries_count == 3
      assert result.references_count == 2

      refs = Repo.all(Reference)
      assert length(refs) == 2

      inline_refs = Enum.filter(refs, &(&1.type == :inline))
      frontmatter_refs = Enum.filter(refs, &(&1.type == :frontmatter))

      assert length(inline_refs) == 1
      assert length(frontmatter_refs) == 1
      assert hd(inline_refs).target_slug == "elixir"
      assert hd(frontmatter_refs).target_slug == "tag1"
    end

    test "re-importing updates references" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file = Path.join(content_dir, "post.md")
      File.mkdir_p!(content_dir)

      File.write!(file, """
      ---
      title: My Post
      ---

      Check out [[elixir]] and [[phoenix]]!
      """)

      assert {:ok, result} = Entries.import_entries(content_dir)
      assert result.references_count == 2

      File.write!(file, """
      ---
      title: My Post
      ---

      Check out [[ecto]] only!
      """)

      assert {:ok, result} = Entries.import_entries(content_dir)
      assert result.references_count == 1

      refs = Repo.all(Reference)
      assert length(refs) == 1
      assert hd(refs).target_slug == "ecto"
    end

    test "imports entries with no references" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file = Path.join(content_dir, "post.md")
      File.mkdir_p!(content_dir)

      File.write!(file, """
      ---
      title: My Post
      ---

      Just plain content
      """)

      assert {:ok, result} = Entries.import_entries(content_dir)
      assert result.entries_count == 1
      assert result.references_count == 0

      refs = Repo.all(Reference)
      assert refs == []
    end

    test "imports entries with permalinks and creates slug entries" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file = Path.join(content_dir, "post.md")
      File.mkdir_p!(content_dir)

      File.write!(file, """
      ---
      title: My Post
      permalinks:
        - old-slug-1
        - old-slug-2
      ---

      Content here
      """)

      assert {:ok, result} = Entries.import_entries(content_dir)
      assert result.entries_count == 1

      entry = Entries.get_entry(slug: "post")
      assert entry.permalinks == ["old-slug-1", "old-slug-2"]

      slugs = Entries.list_slugs(entry_id: entry.id)
      assert length(slugs) == 3

      slug_values = slugs |> Enum.map(& &1.slug) |> Enum.sort()
      assert slug_values == ["old-slug-1", "old-slug-2", "post"]
    end

    test "re-importing with different permalinks updates slug entries" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      file = Path.join(content_dir, "post.md")
      File.mkdir_p!(content_dir)

      File.write!(file, """
      ---
      title: My Post
      permalinks:
        - old-1
      ---

      Content
      """)

      assert {:ok, _result} = Entries.import_entries(content_dir)
      entry = Entries.get_entry(slug: "post")
      assert length(Entries.list_slugs(entry_id: entry.id)) == 2

      File.write!(file, """
      ---
      title: My Post
      permalinks:
        - old-2
        - old-3
      ---

      Updated content
      """)

      assert {:ok, _result} = Entries.import_entries(content_dir)
      entry = Entries.get_entry(slug: "post")

      slugs = Entries.list_slugs(entry_id: entry.id)
      assert length(slugs) == 3

      slug_values = slugs |> Enum.map(& &1.slug) |> Enum.sort()
      assert slug_values == ["old-2", "old-3", "post"]
    end

    test "fails when permalink conflicts with existing slug" do
      {:ok, tmp_dir} = Briefly.create(directory: true)
      content_dir = Path.join(tmp_dir, "content")
      File.mkdir_p!(content_dir)

      File.write!(Path.join(content_dir, "post1.md"), """
      ---
      title: Post 1
      ---

      Content 1
      """)

      assert {:ok, _result} = Entries.import_entries(content_dir)

      File.write!(Path.join(content_dir, "post2.md"), """
      ---
      title: Post 2
      permalinks:
        - post1
      ---

      Content 2
      """)

      assert_raise Exqlite.Error, ~r/UNIQUE constraint failed: slugs\.slug/, fn ->
        Entries.import_entries(content_dir)
      end
    end
  end

  describe "get_slug/1" do
    test "returns slug by filter" do
      entry = insert(:entry, slug: "test-post")

      assert %Slug{} = Entries.get_slug(slug: "test-post")
      assert Entries.get_slug(slug: "test-post").entry_id == entry.id
    end

    test "returns nil when slug not found" do
      assert is_nil(Entries.get_slug(slug: "nonexistent"))
    end

    test "excludes deleted slugs by default" do
      _entry = insert(:entry, slug: "test-post", deleted_at: DateTime.utc_now())

      assert is_nil(Entries.get_slug(slug: "test-post"))
      assert %Slug{} = Entries.get_slug(slug: "test-post", include_deleted: true)
    end
  end

  describe "list_slugs/0" do
    test "returns all non-deleted slugs" do
      insert(:entry, slug: "post1")
      insert(:entry, slug: "post2")
      insert(:entry, slug: "deleted", deleted_at: DateTime.utc_now())

      slugs = Entries.list_slugs()
      assert length(slugs) == 2
      assert slugs |> Enum.map(& &1.slug) |> Enum.sort() == ["post1", "post2"]
    end
  end

  describe "list_slugs/1" do
    test "includes deleted slugs when specified" do
      insert(:entry, slug: "post1")
      insert(:entry, slug: "deleted", deleted_at: DateTime.utc_now())

      slugs = Entries.list_slugs(include_deleted: true)
      assert length(slugs) == 2
      assert slugs |> Enum.map(& &1.slug) |> Enum.sort() == ["deleted", "post1"]
    end

    test "filters by entry_id" do
      entry1 = insert(:entry, slug: "post1")
      insert(:entry, slug: "post2")

      slugs = Entries.list_slugs(entry_id: entry1.id)
      assert length(slugs) == 1
      assert hd(slugs).slug == "post1"
    end
  end
end
