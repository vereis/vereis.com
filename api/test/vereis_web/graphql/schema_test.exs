defmodule VereisWeb.GraphQL.SchemaTest do
  use VereisWeb.ConnCase, async: true

  describe "liveness query" do
    test "returns true", %{conn: conn} do
      query = """
      {
        liveness
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert json_response(conn, 200) == %{
               "data" => %{
                 "liveness" => true
               }
             }
    end
  end

  describe "readiness query" do
    test "returns true when database is connected", %{conn: conn} do
      query = """
      {
        readiness
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert json_response(conn, 200) == %{
               "data" => %{
                 "readiness" => true
               }
             }
    end
  end

  describe "combined health queries" do
    test "returns both liveness and readiness", %{conn: conn} do
      query = """
      {
        liveness
        readiness
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert json_response(conn, 200) == %{
               "data" => %{
                 "liveness" => true,
                 "readiness" => true
               }
             }
    end
  end

  describe "version query" do
    test "returns sha and env", %{conn: conn} do
      query = """
      {
        version {
          sha
          env
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"version" => version}} = response
      assert Map.has_key?(version, "sha")
      assert Map.has_key?(version, "env")
      assert version["env"] == "test"
      assert is_binary(version["sha"])
      assert String.length(version["sha"]) > 0
    end

    test "respects RELEASE_SHA environment variable", %{conn: conn} do
      System.put_env("RELEASE_SHA", "abc123test")

      query = """
      {
        version {
          sha
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"version" => %{"sha" => "abc123test"}}} = response

      System.delete_env("RELEASE_SHA")
    end
  end

  describe "invalid query" do
    test "returns error for unknown field", %{conn: conn} do
      query = """
      {
        invalidField
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert Map.has_key?(response, "errors")
      assert response["errors"] != []
    end
  end
end
