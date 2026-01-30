defmodule VereisWeb.GraphQL.SlugTest do
  use VereisWeb.ConnCase, async: false

  import Vereis.Factory

  describe "slug query" do
    test "returns slug when found", %{conn: conn} do
      _entry = insert(:entry, slug: "test-entry", title: "Test Entry")

      query = """
      {
        slug(slug: "test-entry") {
          slug
          deletedAt
          insertedAt
          entry {
            id
            slug
            title
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
                 "slug" => %{
                   "slug" => "test-entry",
                   "deletedAt" => nil,
                   "insertedAt" => _inserted_at,
                   "entry" => %{
                     "id" => _id,
                     "slug" => "test-entry",
                     "title" => "Test Entry"
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns error when slug not found", %{conn: conn} do
      query = """
      {
        slug(slug: "nonexistent") {
          slug
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"slug" => nil}, "errors" => errors} = response
      assert [%{"message" => "Slug not found"}] = errors
    end

    test "filters out soft-deleted slugs by default", %{conn: conn} do
      _entry = insert(:entry, slug: "deleted-entry", deleted_at: ~U[2024-01-01 00:00:00Z])

      query = """
      {
        slug(slug: "deleted-entry") {
          slug
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"slug" => nil}, "errors" => errors} = response
      assert [%{"message" => "Slug not found"}] = errors
    end
  end

  describe "slugs query (Relay connection)" do
    test "returns empty connection when no slugs exist", %{conn: conn} do
      query = """
      {
        slugs(first: 10) {
          edges {
            node {
              slug
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
                 "slugs" => %{
                   "edges" => [],
                   "pageInfo" => %{
                     "hasNextPage" => false,
                     "hasPreviousPage" => false
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns all non-deleted slugs in connection format", %{conn: conn} do
      _entry1 = insert(:entry, slug: "entry-1", title: "Entry 1")
      _entry2 = insert(:entry, slug: "entry-2", title: "Entry 2")
      _deleted = insert(:entry, slug: "deleted", deleted_at: ~U[2024-01-01 00:00:00Z])

      query = """
      {
        slugs(first: 10) {
          edges {
            node {
              slug
              deletedAt
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
      assert %{"data" => %{"slugs" => %{"edges" => edges}}} = response
      assert length(edges) == 2
      slugs = Enum.map(edges, fn %{"node" => node} -> node["slug"] end)
      assert "entry-1" in slugs
      assert "entry-2" in slugs
      refute "deleted" in slugs

      assert Enum.all?(edges, fn %{"node" => node} -> node["deletedAt"] == nil end)
      assert Enum.all?(edges, fn %{"cursor" => cursor} -> is_binary(cursor) end)
    end

    test "includes deleted slugs when includeDeleted is true", %{conn: conn} do
      _entry1 = insert(:entry, slug: "entry-1")
      _deleted = insert(:entry, slug: "deleted", deleted_at: ~U[2024-01-01 00:00:00Z])

      query = """
      {
        slugs(first: 10, includeDeleted: true) {
          edges {
            node {
              slug
              deletedAt
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
      assert %{"data" => %{"slugs" => %{"edges" => edges}}} = response
      assert length(edges) == 2
      slugs = Enum.map(edges, fn %{"node" => node} -> node["slug"] end)
      assert "entry-1" in slugs
      assert "deleted" in slugs
    end

    test "supports pagination with first argument", %{conn: conn} do
      _entry1 = insert(:entry, slug: "entry-1")
      _entry2 = insert(:entry, slug: "entry-2")
      _entry3 = insert(:entry, slug: "entry-3")

      query = """
      {
        slugs(first: 2) {
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
      assert %{"data" => %{"slugs" => connection}} = response
      assert length(connection["edges"]) == 2
      assert connection["pageInfo"]["hasNextPage"] == true
      assert is_binary(connection["pageInfo"]["endCursor"])
    end

    test "batches entry lookups for multiple slugs (N+1 prevention)", %{conn: conn} do
      _entry1 = insert(:entry, slug: "entry-1", title: "Entry 1")
      _entry2 = insert(:entry, slug: "entry-2", title: "Entry 2")

      query = """
      {
        slugs(first: 10) {
          edges {
            node {
              slug
              entry {
                slug
                title
              }
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
      assert %{"data" => %{"slugs" => %{"edges" => edges}}} = response
      assert length(edges) == 2

      slug1 = Enum.find(edges, fn e -> e["node"]["slug"] == "entry-1" end)
      slug2 = Enum.find(edges, fn e -> e["node"]["slug"] == "entry-2" end)

      assert slug1["node"]["entry"]["title"] == "Entry 1"
      assert slug2["node"]["entry"]["title"] == "Entry 2"
    end
  end

  describe "entry.permalinks field" do
    test "returns empty array when entry has no permalinks", %{conn: conn} do
      insert(:entry, slug: "no-perms", title: "No Permalinks")

      query = """
      {
        entry(slug: "no-perms") {
          slug
          permalinks
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
                   "slug" => "no-perms",
                   "permalinks" => []
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns permalinks array when entry has permalinks", %{conn: conn} do
      insert(:entry, slug: "with-perms", title: "With Permalinks", permalinks: ["old-1", "old-2"])

      query = """
      {
        entry(slug: "with-perms") {
          slug
          permalinks
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
                   "slug" => "with-perms",
                   "permalinks" => ["old-1", "old-2"]
                 }
               }
             } = json_response(conn, 200)
    end
  end

  describe "entry lookup by permalink" do
    test "finds entry by current slug", %{conn: conn} do
      insert(:entry, slug: "current", title: "Current", permalinks: ["old"])

      query = """
      {
        entry(slug: "current") {
          slug
          title
          permalinks
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
                   "slug" => "current",
                   "title" => "Current",
                   "permalinks" => ["old"]
                 }
               }
             } = json_response(conn, 200)
    end

    test "finds entry by permalink slug", %{conn: conn} do
      insert(:entry, slug: "current", title: "Current", permalinks: ["old-slug", "another-old"])

      query = """
      {
        entry(slug: "old-slug") {
          slug
          title
          permalinks
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
                   "slug" => "current",
                   "title" => "Current",
                   "permalinks" => ["old-slug", "another-old"]
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns same entry for both current slug and permalink", %{conn: conn} do
      insert(:entry, slug: "current", title: "Test Entry", permalinks: ["old"])

      query1 = """
      {
        entry(slug: "current") {
          id
          slug
          title
        }
      }
      """

      conn1 =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query1})

      response1 = json_response(conn1, 200)
      current_id = get_in(response1, ["data", "entry", "id"])

      query2 = """
      {
        entry(slug: "old") {
          id
          slug
          title
        }
      }
      """

      conn2 =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query2})

      response2 = json_response(conn2, 200)
      permalink_id = get_in(response2, ["data", "entry", "id"])

      assert current_id == permalink_id
      assert get_in(response2, ["data", "entry", "slug"]) == "current"
    end
  end

  describe "node query (Relay) for slug" do
    test "fetches slug by global ID", %{conn: conn} do
      _entry = insert(:entry, slug: "test-slug", title: "Test")

      query1 = """
      {
        slug(slug: "test-slug") {
          id
        }
      }
      """

      conn1 =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query1})

      response1 = json_response(conn1, 200)
      global_id = get_in(response1, ["data", "slug", "id"])

      query2 = """
      {
        node(id: "#{global_id}") {
          ... on Slug {
            id
            slug
            entry {
              slug
              title
            }
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
                   "slug" => "test-slug",
                   "entry" => %{
                     "slug" => "test-slug",
                     "title" => "Test"
                   }
                 }
               }
             } = json_response(conn2, 200)
    end

    test "returns null for non-existent slug node", %{conn: conn} do
      fake_id = Base.encode64("Slug:nonexistent")

      query = """
      {
        node(id: "#{fake_id}") {
          ... on Slug {
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
