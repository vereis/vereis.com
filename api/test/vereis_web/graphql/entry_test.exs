defmodule VereisWeb.GraphQL.EntryTest do
  use VereisWeb.ConnCase, async: false

  import Vereis.Factory

  describe "entry query" do
    test "returns entry when found", %{conn: conn} do
      _entry = insert(:entry, slug: "test-entry", title: "Test Entry")

      query = """
      {
        entry(slug: "test-entry") {
          id
          slug
          title
          body
          rawBody
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
                 "entry" => %{
                   "id" => _id,
                   "slug" => "test-entry",
                   "title" => "Test Entry",
                   "body" => "<p>Test body content</p>",
                   "rawBody" => "Test body content",
                   "description" => "Test description",
                   "publishedAt" => nil,
                   "insertedAt" => _inserted_at,
                   "updatedAt" => _updated_at
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns error when entry not found", %{conn: conn} do
      query = """
      {
        entry(slug: "nonexistent") {
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

      response = json_response(conn, 200)
      assert %{"data" => %{"entry" => nil}, "errors" => errors} = response
      assert [%{"message" => "Entry not found"}] = errors
    end

    test "filters out soft-deleted entries", %{conn: conn} do
      _entry = insert(:entry, slug: "deleted-entry", deleted_at: ~U[2024-01-01 00:00:00Z])

      query = """
      {
        entry(slug: "deleted-entry") {
          id
          slug
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"entry" => nil}, "errors" => errors} = response
      assert [%{"message" => "Entry not found"}] = errors
    end

    test "returns entry with published_at when set", %{conn: conn} do
      published_at = ~U[2024-01-15 12:00:00Z]
      insert(:entry, slug: "published", published_at: published_at)

      query = """
      {
        entry(slug: "published") {
          slug
          publishedAt
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "entry" => %{
                   "slug" => "published",
                   "publishedAt" => published_at_string
                 }
               }
             } = json_response(conn, 200)

      assert published_at_string
    end

    test "returns entry with headings", %{conn: conn} do
      headings = [
        %{level: 1, title: "Introduction", link: "introduction"},
        %{level: 2, title: "Getting Started", link: "getting-started"},
        %{level: 3, title: "Installation", link: "installation"}
      ]

      insert(:entry, slug: "with-headings", title: "Test", headings: headings)

      query = """
      {
        entry(slug: "with-headings") {
          slug
          headings {
            level
            title
            link
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
                 "entry" => %{
                   "slug" => "with-headings",
                   "headings" => [
                     %{"level" => 1, "title" => "Introduction", "link" => "introduction"},
                     %{"level" => 2, "title" => "Getting Started", "link" => "getting-started"},
                     %{"level" => 3, "title" => "Installation", "link" => "installation"}
                   ]
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns empty headings list when entry has no headings", %{conn: conn} do
      insert(:entry, slug: "no-headings", title: "No Headings")

      query = """
      {
        entry(slug: "no-headings") {
          slug
          headings {
            level
            title
            link
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
                 "entry" => %{
                   "slug" => "no-headings",
                   "headings" => []
                 }
               }
             } = json_response(conn, 200)
    end
  end

  describe "entries query (Relay connection)" do
    test "returns empty connection when no entries exist", %{conn: conn} do
      query = """
      {
        entries(first: 10) {
          edges {
            node {
              id
              slug
              title
            }
          }
          pageInfo {
            hasNextPage
            hasPreviousPage
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
                 "entries" => %{
                   "edges" => [],
                   "pageInfo" => %{
                     "hasNextPage" => false,
                     "hasPreviousPage" => false
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns all non-deleted entries in connection format", %{conn: conn} do
      _entry1 = insert(:entry, slug: "entry-1", title: "Entry 1")
      _entry2 = insert(:entry, slug: "entry-2", title: "Entry 2")
      _deleted = insert(:entry, slug: "deleted", deleted_at: ~U[2024-01-01 00:00:00Z])

      query = """
      {
        entries(first: 10) {
          edges {
            node {
              slug
              title
            }
            cursor
          }
          pageInfo {
            hasNextPage
            hasPreviousPage
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"entries" => %{"edges" => edges}}} = response
      assert length(edges) == 2
      slugs = Enum.map(edges, fn %{"node" => node} -> node["slug"] end)
      assert "entry-1" in slugs
      assert "entry-2" in slugs
      refute "/deleted" in slugs

      # Verify cursors exist
      assert Enum.all?(edges, fn %{"cursor" => cursor} -> is_binary(cursor) end)
    end

    test "supports pagination with first argument", %{conn: conn} do
      _entry1 = insert(:entry, slug: "entry-1", title: "Entry 1")
      _entry2 = insert(:entry, slug: "entry-2", title: "Entry 2")
      _entry3 = insert(:entry, slug: "entry-3", title: "Entry 3")

      query = """
      {
        entries(first: 2) {
          edges {
            node {
              slug
            }
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"entries" => connection}} = response
      assert length(connection["edges"]) == 2
      assert connection["pageInfo"]["hasNextPage"] == true
      assert is_binary(connection["pageInfo"]["endCursor"])
    end

    test "supports pagination with after argument", %{conn: conn} do
      _entry1 = insert(:entry, slug: "entry-1", title: "Entry 1")
      _entry2 = insert(:entry, slug: "entry-2", title: "Entry 2")
      _entry3 = insert(:entry, slug: "entry-3", title: "Entry 3")

      # First query to get the cursor
      first_query = """
      {
        entries(first: 1) {
          edges {
            cursor
          }
          pageInfo {
            endCursor
          }
        }
      }
      """

      conn1 =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: first_query})

      first_response = json_response(conn1, 200)
      cursor = get_in(first_response, ["data", "entries", "pageInfo", "endCursor"])

      # Second query using the cursor
      second_query = """
      {
        entries(first: 2, after: "#{cursor}") {
          edges {
            node {
              slug
            }
          }
          pageInfo {
            hasNextPage
          }
        }
      }
      """

      conn2 =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: second_query})

      second_response = json_response(conn2, 200)
      assert %{"data" => %{"entries" => connection}} = second_response
      assert length(connection["edges"]) == 2
    end

    test "supports ordering by insertedAt desc", %{conn: conn} do
      _entry1 = insert(:entry, slug: "old", title: "Old", inserted_at: ~U[2024-01-01 00:00:00Z])
      _entry2 = insert(:entry, slug: "new", title: "New", inserted_at: ~U[2024-01-15 00:00:00Z])

      query = """
      {
        entries(first: 10, orderBy: [{insertedAt: DESC}]) {
          edges {
            node {
              slug
            }
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"entries" => %{"edges" => edges}}} = response
      slugs = Enum.map(edges, & &1["node"]["slug"])
      assert slugs == ["new", "old"]
    end

    test "supports ordering by title asc", %{conn: conn} do
      _entry1 = insert(:entry, slug: "zebra", title: "Zebra")
      _entry2 = insert(:entry, slug: "apple", title: "Apple")

      query = """
      {
        entries(first: 10, orderBy: [{title: ASC}]) {
          edges {
            node {
              title
            }
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"entries" => %{"edges" => edges}}} = response
      titles = Enum.map(edges, & &1["node"]["title"])
      assert titles == ["Apple", "Zebra"]
    end

    test "supports filtering by search", %{conn: conn} do
      _entry1 = insert(:entry, slug: "elixir", title: "Elixir Guide", raw_body: "Learn Elixir")
      _entry2 = insert(:entry, slug: "rust", title: "Rust Guide", raw_body: "Learn Rust")

      query = """
      {
        entries(first: 10, search: "elixir") {
          edges {
            node {
              slug
              title
            }
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"entries" => %{"edges" => edges}}} = response
      assert length(edges) == 1
      assert hd(edges)["node"]["slug"] == "elixir"
    end

    test "supports filtering by isPublished true", %{conn: conn} do
      _published = insert(:entry, slug: "published", published_at: ~U[2024-01-01 00:00:00Z])
      _draft = insert(:entry, slug: "draft", published_at: nil)

      query = """
      {
        entries(first: 10, isPublished: true) {
          edges {
            node {
              slug
            }
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"entries" => %{"edges" => edges}}} = response
      assert length(edges) == 1
      assert hd(edges)["node"]["slug"] == "published"
    end

    test "supports filtering by isPublished false", %{conn: conn} do
      _published = insert(:entry, slug: "published", published_at: ~U[2024-01-01 00:00:00Z])
      _draft = insert(:entry, slug: "draft", published_at: nil)

      query = """
      {
        entries(first: 10, isPublished: false) {
          edges {
            node {
              slug
            }
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"entries" => %{"edges" => edges}}} = response
      assert length(edges) == 1
      assert hd(edges)["node"]["slug"] == "draft"
    end

    test "supports combining filters and ordering", %{conn: conn} do
      _draft1 = insert(:entry, slug: "draft-1", title: "Zebra Draft", published_at: nil)
      _draft2 = insert(:entry, slug: "draft-2", title: "Apple Draft", published_at: nil)

      _published =
        insert(:entry, slug: "published", title: "Published", published_at: ~U[2024-01-01 00:00:00Z])

      query = """
      {
        entries(first: 10, isPublished: false, orderBy: [{title: ASC}]) {
          edges {
            node {
              slug
              title
            }
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"entries" => %{"edges" => edges}}} = response
      assert length(edges) == 2
      titles = Enum.map(edges, & &1["node"]["title"])
      assert titles == ["Apple Draft", "Zebra Draft"]
    end

    test "returns all fields for entries in connection format", %{conn: conn} do
      insert(:entry,
        slug: "test",
        title: "Test",
        body: "<p>Body</p>",
        raw_body: "Body",
        description: "Desc"
      )

      query = """
      {
        entries(first: 10) {
          edges {
            node {
              id
              slug
              title
              body
              rawBody
              description
              publishedAt
              insertedAt
              updatedAt
            }
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
                 "entries" => %{
                   "edges" => [
                     %{
                       "node" => %{
                         "id" => _id,
                         "slug" => "test",
                         "title" => "Test",
                         "body" => "<p>Body</p>",
                         "rawBody" => "Body",
                         "description" => "Desc",
                         "publishedAt" => nil,
                         "insertedAt" => _inserted_at,
                         "updatedAt" => _updated_at
                       }
                     }
                   ]
                 }
               }
             } = json_response(conn, 200)
    end
  end

  describe "node query (Relay)" do
    test "fetches entry by global ID", %{conn: conn} do
      _entry = insert(:entry, slug: "node-test", title: "Node Test")

      # First get the global ID
      query1 = """
      {
        entry(slug: "node-test") {
          id
        }
      }
      """

      conn1 =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query1})

      response1 = json_response(conn1, 200)
      global_id = get_in(response1, ["data", "entry", "id"])

      # Now fetch via node query
      query2 = """
      {
        node(id: "#{global_id}") {
          ... on Entry {
            id
            slug
            title
          }
        }
      }
      """

      conn2 =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query2})

      assert %{
               "data" => %{
                 "node" => %{
                   "id" => ^global_id,
                   "slug" => "node-test",
                   "title" => "Node Test"
                 }
               }
             } = json_response(conn2, 200)
    end

    test "returns null for non-existent node", %{conn: conn} do
      # Create a fake global ID (base64 encoded "Entry:00000000-0000-0000-0000-000000000000")
      fake_id = Base.encode64("Entry:00000000-0000-0000-0000-000000000000")

      query = """
      {
        node(id: "#{fake_id}") {
          ... on Entry {
            id
            slug
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"node" => nil}} = response
    end
  end
end
