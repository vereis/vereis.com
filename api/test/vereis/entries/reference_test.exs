defmodule Vereis.Entries.ReferenceTest do
  use Vereis.DataCase, async: false

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
end
