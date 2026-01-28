defmodule VereisWeb.GraphQL.PageTest do
  use VereisWeb.ConnCase, async: true

  import Vereis.Factory

  describe "Page interface" do
    test "Entry implements Page interface", %{conn: conn} do
      insert(:entry, slug: "/test", title: "Test Entry")

      query = """
      {
        entry(slug: "/test") {
          __typename
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

      response = json_response(conn, 200)

      assert %{
               "data" => %{
                 "entry" => %{
                   "__typename" => "Entry",
                   "id" => _id,
                   "slug" => "/test",
                   "title" => "Test Entry",
                   "description" => "Test description",
                   "publishedAt" => nil,
                   "insertedAt" => _inserted,
                   "updatedAt" => _updated
                 }
               }
             } = response
    end

    test "Entry has both Page fields and Entry-specific fields", %{conn: conn} do
      insert(:entry, slug: "/with-body", title: "Test")

      query = """
      {
        entry(slug: "/with-body") {
          __typename
          id
          slug
          title
          body
          rawBody
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

      response = json_response(conn, 200)

      assert %{
               "data" => %{
                 "entry" => %{
                   "__typename" => "Entry",
                   "id" => _id,
                   "slug" => "/with-body",
                   "title" => "Test",
                   "body" => "<p>Test body content</p>",
                   "rawBody" => "Test body content",
                   "headings" => []
                 }
               }
             } = response
    end

    test "node query resolves Entry as Page interface", %{conn: conn} do
      _entry = insert(:entry, slug: "/interface-test", title: "Interface Test")

      # First get the global ID
      query1 = """
      {
        entry(slug: "/interface-test") {
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

      # Query using Page interface fragment
      query2 = """
      {
        node(id: "#{global_id}") {
          __typename
          id
          ... on Page {
            slug
            title
            description
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
                   "__typename" => "Entry",
                   "id" => ^global_id,
                   "slug" => "/interface-test",
                   "title" => "Interface Test",
                   "description" => "Test description"
                 }
               }
             } = json_response(conn2, 200)
    end
  end
end
