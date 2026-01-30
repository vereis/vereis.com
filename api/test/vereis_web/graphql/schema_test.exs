defmodule VereisWeb.GraphQL.SchemaTest do
  use VereisWeb.ConnCase, async: true

  describe "service query" do
    test "returns all service fields", %{conn: conn} do
      query = """
      {
        service {
          id
          sha
          env
          liveness
          readiness
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"service" => service}} = response
      assert is_binary(service["id"])
      assert is_binary(service["sha"])
      assert service["env"] == "test"
      assert service["liveness"] == true
      assert service["readiness"] == true
    end

    test "returns only requested fields", %{conn: conn} do
      query = """
      {
        service {
          liveness
          readiness
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      assert json_response(conn, 200) == %{
               "data" => %{
                 "service" => %{
                   "liveness" => true,
                   "readiness" => true
                 }
               }
             }
    end

    test "respects RELEASE_SHA environment variable", %{conn: conn} do
      System.put_env("RELEASE_SHA", "abc123test")

      query = """
      {
        service {
          sha
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"service" => %{"sha" => "abc123test"}}} = response

      System.delete_env("RELEASE_SHA")
    end
  end

  describe "node refetch" do
    test "can refetch service via node interface", %{conn: conn} do
      # Get the service to retrieve its encoded ID
      service_query = """
      {
        service {
          id
        }
      }
      """

      conn_service =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: service_query})

      service_id = json_response(conn_service, 200)["data"]["service"]["id"]

      # Now refetch via node interface
      query = """
      {
        node(id: "#{service_id}") {
          id
          ... on Service {
            sha
            env
            liveness
            readiness
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/graphql", %{query: query})

      response = json_response(conn, 200)
      assert %{"data" => %{"node" => service}} = response
      assert is_binary(service["id"])
      assert is_binary(service["sha"])
      assert service["env"] == "test"
      assert service["liveness"] == true
      assert service["readiness"] == true
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
