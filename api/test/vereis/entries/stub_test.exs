defmodule Vereis.Entries.StubTest do
  use Vereis.DataCase, async: false

  alias Vereis.Entries
  alias Vereis.Entries.Entry
  alias Vereis.Entries.Reference
  alias Vereis.Entries.Stub
  alias Vereis.Repo

  describe "stubs view" do
    test "includes target_slug from references with no corresponding entry" do
      # Create a reference to a non-existent page
      {:ok, _ref} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "blog",
          target_slug: "non-existent",
          type: :inline
        })
        |> Repo.insert()

      stubs = Repo.all(Stub)
      assert length(stubs) == 1
      assert hd(stubs).slug == "non-existent"
    end

    test "excludes target_slug when corresponding entry exists" do
      # Create an entry
      {:ok, entry} =
        %Entry{}
        |> Entry.changeset(%{slug: "elixir", title: "Elixir"})
        |> Repo.insert()

      # Create a reference to it
      {:ok, _ref} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "blog",
          target_slug: entry.slug,
          type: :inline
        })
        |> Repo.insert()

      stubs = Repo.all(Stub)
      assert stubs == []
    end

    test "excludes target_slug when entry is deleted" do
      # Create an entry
      {:ok, entry} =
        %Entry{}
        |> Entry.changeset(%{slug: "deleted", title: "Deleted"})
        |> Repo.insert()

      # Create a reference to it
      {:ok, _ref} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "blog",
          target_slug: entry.slug,
          type: :inline
        })
        |> Repo.insert()

      # Initially no stubs
      assert Repo.all(Stub) == []

      # Soft delete the entry
      {:ok, _} = Entries.delete_entry(entry)

      # Now it should appear as a stub
      stubs = Repo.all(Stub)
      assert length(stubs) == 1
      assert hd(stubs).slug == "deleted"
    end

    test "deduplicates target_slug across multiple references" do
      # Create multiple references to the same non-existent page
      {:ok, _ref1} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "blog/post1",
          target_slug: "tag",
          type: :inline
        })
        |> Repo.insert()

      {:ok, _ref2} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "blog/post2",
          target_slug: "tag",
          type: :frontmatter
        })
        |> Repo.insert()

      stubs = Repo.all(Stub)
      assert length(stubs) == 1
      assert hd(stubs).slug == "tag"
    end

    test "tracks inserted_at as MIN of reference inserted_at" do
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      later = NaiveDateTime.add(now, 60, :second)

      # Create first reference
      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog/post1",
        target_slug: "tag",
        type: :inline
      })
      |> Ecto.Changeset.put_change(:inserted_at, later)
      |> Repo.insert!()

      # Create second reference (earlier)
      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog/post2",
        target_slug: "tag",
        type: :frontmatter
      })
      |> Ecto.Changeset.put_change(:inserted_at, now)
      |> Repo.insert!()

      stub = Repo.one(Stub)
      assert stub.inserted_at == now
    end

    test "tracks updated_at as MAX of reference inserted_at" do
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      later = NaiveDateTime.add(now, 60, :second)

      # Create first reference
      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog/post1",
        target_slug: "tag",
        type: :inline
      })
      |> Ecto.Changeset.put_change(:inserted_at, now)
      |> Repo.insert!()

      # Create second reference (later)
      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog/post2",
        target_slug: "tag",
        type: :frontmatter
      })
      |> Ecto.Changeset.put_change(:inserted_at, later)
      |> Repo.insert!()

      stub = Repo.one(Stub)
      assert stub.updated_at == later
    end
  end

  describe "derive_title/1" do
    test "converts slug to title case" do
      assert Stub.derive_title("/elixir-stuff") == "Elixir Stuff"
    end

    test "handles nested paths with slashes" do
      assert Stub.derive_title("/blog/my-post") == "Blog / My Post"
      assert Stub.derive_title("/some/nested/page") == "Some / Nested / Page"
    end

    test "handles underscores" do
      assert Stub.derive_title("/foo_bar") == "Foo Bar"
    end

    test "handles mixed separators" do
      assert Stub.derive_title("/foo-bar_baz") == "Foo Bar Baz"
    end

    test "handles root slug" do
      assert Stub.derive_title("/") == "/"
    end

    test "handles single word" do
      assert Stub.derive_title("elixir") == "Elixir"
    end

    test "handles multiple consecutive separators" do
      assert Stub.derive_title("/foo--bar") == "Foo  Bar"
    end
  end
end
