defmodule Vereis.Entries.EntryTest do
  use Vereis.DataCase, async: true

  alias Vereis.Entries.Entry

  describe "changeset/2" do
    test "valid entry with all fields" do
      attrs = %{
        slug: "/test-entry",
        title: "Test Entry",
        body: "<p>Test content</p>",
        raw_body: "Test content",
        description: "A test entry",
        published_at: ~U[2024-01-15 10:00:00Z],
        source_hash: "abc123"
      }

      changeset = Entry.changeset(%Entry{}, attrs)
      assert changeset.valid?
    end

    test "valid entry with root slug" do
      attrs = %{
        slug: "/",
        title: "Root Entry"
      }

      changeset = Entry.changeset(%Entry{}, attrs)
      assert changeset.valid?
    end

    test "requires title" do
      attrs = %{
        slug: "/test"
      }

      changeset = Entry.changeset(%Entry{}, attrs)
      refute changeset.valid?
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires slug" do
      attrs = %{
        title: "Test"
      }

      changeset = Entry.changeset(%Entry{}, attrs)
      refute changeset.valid?
      assert %{slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates slug format - must start with /, no trailing /" do
      valid_slugs = [
        "/",
        "/simple",
        "/with-hyphens",
        "/with_underscores",
        "/path/to/entry",
        "/complex/path-with_various/formats",
        "/123-numbers"
      ]

      for slug <- valid_slugs do
        changeset = Entry.changeset(%Entry{}, %{slug: slug, title: "Test"})
        assert changeset.valid?, "Expected #{slug} to be valid"
      end
    end

    test "rejects invalid slug formats" do
      invalid_slugs = [
        "no-leading-slash",
        "/UPPERCASE",
        "/With Spaces",
        "/special!chars",
        "/dot.separated",
        "/trailing-slash/"
      ]

      for slug <- invalid_slugs do
        changeset = Entry.changeset(%Entry{}, %{slug: slug, title: "Test"})
        refute changeset.valid?, "Expected #{slug} to be invalid"
        assert %{slug: _} = errors_on(changeset)
      end
    end
  end

  describe "database constraints" do
    test "unique constraint on slug" do
      attrs = %{slug: "/test", title: "Test"}

      {:ok, _} = %Entry{} |> Entry.changeset(attrs) |> Repo.insert()

      {:error, changeset} = %Entry{} |> Entry.changeset(attrs) |> Repo.insert()
      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "coerces published_at string to DateTime" do
      attrs = %{slug: "/test", title: "Test", published_at: "2024-01-15T12:00:00Z"}
      changeset = Entry.changeset(%Entry{}, attrs)

      assert changeset.valid?
      assert %DateTime{year: 2024, month: 1, day: 15} = Ecto.Changeset.get_change(changeset, :published_at)
    end

    test "rejects invalid published_at string" do
      attrs = %{slug: "/test", title: "Test", published_at: "not-a-date"}
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert %{published_at: ["is invalid"]} = errors_on(changeset)
    end
  end
end
