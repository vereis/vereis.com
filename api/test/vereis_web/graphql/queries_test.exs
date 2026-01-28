defmodule VereisWeb.GraphQL.QueriesTest do
  use VereisWeb.ConnCase, async: false

  import Vereis.Factory

  alias Vereis.Entries
  alias Vereis.Entries.Reference
  alias Vereis.Repo

  describe "stub query" do
    test "returns stub when it exists", %{conn: conn} do
      # Create a reference to generate a stub
      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog",
        target_slug: "non-existent",
        type: :inline
      })
      |> Repo.insert!()

      query = """
      {
        stub(slug: "non-existent") {
          id
          slug
          title
          description
          publishedAt
          insertedAt
          updatedAt
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "stub" => %{
                   "id" => "non-existent",
                   "slug" => "non-existent",
                   "title" => "Non Existent",
                   "description" => nil,
                   "publishedAt" => nil,
                   "insertedAt" => _inserted,
                   "updatedAt" => _updated
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns error when stub not found", %{conn: conn} do
      query = """
      {
        stub(slug: "missing") {
          slug
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"stub" => nil}, "errors" => errors} = response
      assert [%{"message" => "Stub not found"}] = errors
    end
  end

  describe "page query" do
    test "returns Entry when entry exists", %{conn: conn} do
      insert(:entry, slug: "test-entry", title: "Test Entry")

      query = """
      {
        page(slug: "test-entry") {
          __typename
          id
          slug
          title
          ... on Entry {
            body
            rawBody
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "page" => %{
                   "__typename" => "Entry",
                   "id" => _id,
                   "slug" => "test-entry",
                   "title" => "Test Entry",
                   "body" => "<p>Test body content</p>",
                   "rawBody" => "Test body content"
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns Stub when only stub exists", %{conn: conn} do
      # Create a reference to generate a stub
      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog",
        target_slug: "stub-page",
        type: :inline
      })
      |> Repo.insert!()

      query = """
      {
        page(slug: "stub-page") {
          __typename
          id
          slug
          title
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "page" => %{
                   "__typename" => "Stub",
                   "id" => "stub-page",
                   "slug" => "stub-page",
                   "title" => "Stub Page"
                 }
               }
             } = json_response(conn, 200)
    end

    test "prefers Entry over Stub", %{conn: conn} do
      # Create both an entry and a stub for the same slug
      insert(:entry, slug: "both", title: "Actual Entry")

      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog",
        target_slug: "both",
        type: :inline
      })
      |> Repo.insert!()

      query = """
      {
        page(slug: "both") {
          __typename
          title
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "page" => %{
                   "__typename" => "Entry",
                   "title" => "Actual Entry"
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns error when neither exists", %{conn: conn} do
      query = """
      {
        page(slug: "nothing") {
          slug
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"page" => nil}, "errors" => errors} = response
      assert [%{"message" => "Page not found"}] = errors
    end
  end

  describe "stubs query" do
    setup do
      # Create references to generate stubs
      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog",
        target_slug: "tags/elixir",
        type: :inline
      })
      |> Repo.insert!()

      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog",
        target_slug: "tags/phoenix",
        type: :inline
      })
      |> Repo.insert!()

      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog",
        target_slug: "about",
        type: :inline
      })
      |> Repo.insert!()

      :ok
    end

    test "returns all stubs", %{conn: conn} do
      query = """
      {
        stubs {
          slug
          title
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "stubs" => stubs
               }
             } = json_response(conn, 200)

      assert length(stubs) == 3
      slugs = Enum.map(stubs, & &1["slug"])
      assert "tags/elixir" in slugs
      assert "tags/phoenix" in slugs
      assert "about" in slugs
    end

    test "filters stubs by prefix", %{conn: conn} do
      query = """
      {
        stubs(prefix: "tags") {
          slug
          title
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "stubs" => stubs
               }
             } = json_response(conn, 200)

      assert length(stubs) == 2
      assert Enum.all?(stubs, &String.starts_with?(&1["slug"], "tags"))
    end
  end

  describe "pages query" do
    setup do
      # Create entries
      insert(:entry, slug: "blog/post-1", title: "Post 1")
      insert(:entry, slug: "blog/post-2", title: "Post 2")
      insert(:entry, slug: "docs/guide", title: "Guide")

      # Create stubs
      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog/post-1",
        target_slug: "blog/draft",
        type: :inline
      })
      |> Repo.insert!()

      %Reference{}
      |> Reference.changeset(%{
        source_slug: "docs/guide",
        target_slug: "docs/api",
        type: :inline
      })
      |> Repo.insert!()

      :ok
    end

    test "returns both entries and stubs", %{conn: conn} do
      query = """
      {
        pages {
          __typename
          slug
          title
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "pages" => pages
               }
             } = json_response(conn, 200)

      assert length(pages) == 5

      entry_slugs = pages |> Enum.filter(&(&1["__typename"] == "Entry")) |> Enum.map(& &1["slug"])
      stub_slugs = pages |> Enum.filter(&(&1["__typename"] == "Stub")) |> Enum.map(& &1["slug"])

      assert "blog/post-1" in entry_slugs
      assert "blog/post-2" in entry_slugs
      assert "docs/guide" in entry_slugs
      assert "blog/draft" in stub_slugs
      assert "docs/api" in stub_slugs
    end

    test "filters pages by prefix", %{conn: conn} do
      query = """
      {
        pages(prefix: "blog") {
          __typename
          slug
          title
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "pages" => pages
               }
             } = json_response(conn, 200)

      assert length(pages) == 3
      assert Enum.all?(pages, &String.starts_with?(&1["slug"], "blog"))

      entry_count = Enum.count(pages, &(&1["__typename"] == "Entry"))
      stub_count = Enum.count(pages, &(&1["__typename"] == "Stub"))

      assert entry_count == 2
      assert stub_count == 1
    end

    test "returns empty list when no pages match prefix", %{conn: conn} do
      query = """
      {
        pages(prefix: "/nonexistent") {
          slug
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "pages" => []
               }
             } = json_response(conn, 200)
    end
  end

  describe "Entries context - prefix filter" do
    test "list_entries filters by slug prefix" do
      insert(:entry, slug: "blog/post-1", title: "Post 1")
      insert(:entry, slug: "blog/post-2", title: "Post 2")
      insert(:entry, slug: "docs/guide", title: "Guide")

      entries = Entries.list_entries(prefix: "blog")

      assert length(entries) == 2
      assert Enum.all?(entries, &String.starts_with?(&1.slug, "blog"))
    end

    test "list_stubs filters by slug prefix" do
      # Create references
      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog",
        target_slug: "tags/elixir",
        type: :inline
      })
      |> Repo.insert!()

      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog",
        target_slug: "tags/phoenix",
        type: :inline
      })
      |> Repo.insert!()

      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog",
        target_slug: "about",
        type: :inline
      })
      |> Repo.insert!()

      stubs = Entries.list_stubs(prefix: "tags")

      assert length(stubs) == 2
      assert Enum.all?(stubs, &String.starts_with?(&1.slug, "tags"))
    end

    test "list_entries_or_stubs filters by slug prefix" do
      # Create entries
      insert(:entry, slug: "blog/post-1", title: "Post 1")
      insert(:entry, slug: "docs/guide", title: "Guide")

      # Create stubs
      %Reference{}
      |> Reference.changeset(%{
        source_slug: "blog",
        target_slug: "blog/draft",
        type: :inline
      })
      |> Repo.insert!()

      %Reference{}
      |> Reference.changeset(%{
        source_slug: "docs",
        target_slug: "docs/api",
        type: :inline
      })
      |> Repo.insert!()

      pages = Entries.list_entries_or_stubs(prefix: "blog")

      assert length(pages) == 2
      assert Enum.all?(pages, &String.starts_with?(&1.slug, "blog"))
    end

    test "list_entries_or_stubs returns entries and stubs" do
      insert(:entry, slug: "entry", title: "Entry")

      %Reference{}
      |> Reference.changeset(%{
        source_slug: "entry",
        target_slug: "stub",
        type: :inline
      })
      |> Repo.insert!()

      pages = Entries.list_entries_or_stubs()

      assert length(pages) == 2
      assert Enum.any?(pages, &match?(%Entries.Entry{}, &1))
      assert Enum.any?(pages, &match?(%Entries.Stub{}, &1))
    end
  end
end
