defmodule Vereis.Entries.ReferenceTest do
  use Vereis.DataCase, async: true

  import Vereis.Factory

  alias Vereis.Entries.Reference
  alias Vereis.Repo

  describe "changeset/2" do
    test "valid reference with all fields" do
      attrs = %{
        source_slug: "/blog/post",
        target_slug: "/elixir/pipes",
        type: :inline
      }

      changeset = Reference.changeset(%Reference{}, attrs)
      assert changeset.valid?
    end

    test "valid reference with frontmatter type" do
      attrs = %{
        source_slug: "/blog/post",
        target_slug: "/elixir",
        type: :frontmatter
      }

      changeset = Reference.changeset(%Reference{}, attrs)
      assert changeset.valid?
    end

    test "valid reference with root slug" do
      attrs = %{
        source_slug: "/",
        target_slug: "/blog",
        type: :inline
      }

      changeset = Reference.changeset(%Reference{}, attrs)
      assert changeset.valid?
    end

    test "requires source_slug" do
      attrs = %{
        target_slug: "/target",
        type: :inline
      }

      changeset = Reference.changeset(%Reference{}, attrs)
      refute changeset.valid?
      assert %{source_slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires target_slug" do
      attrs = %{
        source_slug: "/source",
        type: :inline
      }

      changeset = Reference.changeset(%Reference{}, attrs)
      refute changeset.valid?
      assert %{target_slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires type" do
      attrs = %{
        source_slug: "/source",
        target_slug: "/target"
      }

      changeset = Reference.changeset(%Reference{}, attrs)
      refute changeset.valid?
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates source_slug format" do
      valid_slugs = [
        "/",
        "/simple",
        "/with-hyphens",
        "/with_underscores",
        "/path/to/entry"
      ]

      for slug <- valid_slugs do
        changeset =
          Reference.changeset(%Reference{}, %{
            source_slug: slug,
            target_slug: "/target",
            type: :inline
          })

        assert changeset.valid?, "Expected #{slug} to be valid"
      end
    end


    test "rejects invalid source_slug formats" do
      invalid_slugs = [
        "no-leading-slash",
        "/UPPERCASE",
        "/With Spaces",
        "/special!chars",
        "/trailing-slash/"
      ]

      for slug <- invalid_slugs do
        changeset =
          Reference.changeset(%Reference{}, %{
            source_slug: slug,
            target_slug: "/target",
            type: :inline
          })

        refute changeset.valid?, "Expected #{slug} to be invalid"
        assert %{source_slug: _} = errors_on(changeset)
      end
    end

  end

  describe "database constraints" do
    test "unique constraint on (source_slug, target_slug, type)" do
      insert(:entry, slug: "source")
      insert(:entry, slug: "target")

      attrs = %{
        source_slug: "/source",
        target_slug: "/target",
        type: :inline
      }

      {:ok, _} = %Reference{} |> Reference.changeset(attrs) |> Repo.insert()

      {:error, changeset} = %Reference{} |> Reference.changeset(attrs) |> Repo.insert()
      assert %{source_slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows duplicate reference with different type" do
      insert(:entry, slug: "source")
      insert(:entry, slug: "target")

      base_attrs = %{
        source_slug: "/source",
        target_slug: "/target"
      }

      {:ok, _} =
        %Reference{}
        |> Reference.changeset(Map.put(base_attrs, :type, :inline))
        |> Repo.insert()

      {:ok, _} =
        %Reference{}
        |> Reference.changeset(Map.put(base_attrs, :type, :frontmatter))
        |> Repo.insert()

      # Verify both exist
      assert Repo.aggregate(Reference, :count) == 2
    end

    test "FK constraint requires source entry to exist" do
      insert(:entry, slug: "target")

      attrs = %{
        source_slug: "nonexistent",
        target_slug: "target",
        type: :inline
      }

      # SQLite may not return named constraints, so just verify the insert fails
      assert_raise Ecto.ConstraintError, fn ->
        %Reference{} |> Reference.changeset(attrs) |> Repo.insert!()
      end
    end

    test "FK constraint requires target entry to exist" do
      insert(:entry, slug: "source")

      attrs = %{
        source_slug: "source",
        target_slug: "nonexistent",
        type: :inline
      }

      # SQLite may not return named constraints, so just verify the insert fails
      assert_raise Ecto.ConstraintError, fn ->
        %Reference{} |> Reference.changeset(attrs) |> Repo.insert!()
      end
    end
  end


  describe "Queryable.query/2 with :target filter" do
    setup do
      # Create some entries
      {:ok, entry1} =
        %Entry{}
        |> Entry.changeset(%{slug: "/elixir", title: "Elixir"})
        |> Repo.insert()

      {:ok, entry2} =
        %Entry{}
        |> Entry.changeset(%{slug: "/phoenix", title: "Phoenix"})
        |> Repo.insert()

      # Create references: one to existing entry, one to stub
      {:ok, ref_to_entry} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "/blog",
          target_slug: entry1.slug,
          type: :inline
        })
        |> Repo.insert()

      {:ok, ref_to_stub} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "/blog",
          target_slug: "/non-existent",
          type: :inline
        })
        |> Repo.insert()

      %{
        entry1: entry1,
        entry2: entry2,
        ref_to_entry: ref_to_entry,
        ref_to_stub: ref_to_stub
      }
    end

    test "filters by target: :entry", %{ref_to_entry: ref_to_entry} do
      results = [target: :entry] |> Reference.query() |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == ref_to_entry.id
    end

    test "filters by target: :stub", %{ref_to_stub: ref_to_stub} do
      results = [target: :stub] |> Reference.query() |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == ref_to_stub.id
    end

    test "no filter returns all references", %{ref_to_entry: ref_to_entry, ref_to_stub: ref_to_stub} do
      results = [] |> Reference.query() |> Repo.all()

      assert length(results) == 2
      ids = Enum.map(results, & &1.id)
      assert ref_to_entry.id in ids
      assert ref_to_stub.id in ids
    end

    test "excludes references to deleted entries when filtering by :entry" do
      # Create an entry and reference to it
      {:ok, entry} =
        %Entry{}
        |> Entry.changeset(%{slug: "/temporary", title: "Temporary"})
        |> Repo.insert()

      {:ok, _ref} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "/blog",
          target_slug: entry.slug,
          type: :inline
        })
        |> Repo.insert()

      # Verify it shows up in :entry filter
      assert Repo.all(Reference.query(target: :entry)) != []

      # Soft delete the entry
      {:ok, _} = Entries.delete_entry(entry)

      # Now it should not show up in :entry filter (only the original ref_to_entry remains)
      results = [target: :entry] |> Reference.query() |> Repo.all()
      refute Enum.any?(results, &(&1.target_slug == entry.slug))
    end

    test "includes references to deleted entries when filtering by :stub" do
      # Create an entry and reference to it
      {:ok, entry} =
        %Entry{}
        |> Entry.changeset(%{slug: "/temporary", title: "Temporary"})
        |> Repo.insert()

      {:ok, ref} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "/blog",
          target_slug: entry.slug,
          type: :frontmatter
        })
        |> Repo.insert()

      # Initially should not show in :stub filter
      results = [target: :stub] |> Reference.query() |> Repo.all()
      refute Enum.any?(results, &(&1.id == ref.id))

      # Soft delete the entry
      {:ok, _} = Entries.delete_entry(entry)

      # Now it should show up in :stub filter
      results = [target: :stub] |> Reference.query() |> Repo.all()
      assert Enum.any?(results, &(&1.id == ref.id))
    end
  end

  describe "Queryable.query/2 with other filters" do
    setup do
      {:ok, ref1} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "/blog/post1",
          target_slug: "/elixir",
          type: :inline
        })
        |> Repo.insert()

      {:ok, ref2} =
        %Reference{}
        |> Reference.changeset(%{
          source_slug: "/blog/post2",
          target_slug: "/elixir",
          type: :frontmatter
        })
        |> Repo.insert()

      %{ref1: ref1, ref2: ref2}
    end

    test "filters by source_slug", %{ref1: ref1} do
      results = [source_slug: "/blog/post1"] |> Reference.query() |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == ref1.id
    end

    test "filters by target_slug" do
      results = [target_slug: "/elixir"] |> Reference.query() |> Repo.all()

      assert length(results) == 2
    end

    test "filters by type", %{ref1: ref1} do
      results = [type: :inline] |> Reference.query() |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == ref1.id
    end

    test "combines multiple filters", %{ref1: ref1} do
      results =
        [source_slug: "/blog/post1", type: :inline]
        |> Reference.query()
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == ref1.id
    end
  end
end
