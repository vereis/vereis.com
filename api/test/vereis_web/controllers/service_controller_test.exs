defmodule VereisWeb.ServiceControllerTest do
  use VereisWeb.ConnCase, async: true

  describe "GET /livez" do
    test "returns 200 OK with status ok", %{conn: conn} do
      conn = get(conn, ~p"/livez")
      assert json_response(conn, 200) == %{"status" => "ok"}
    end
  end

  describe "GET /healthz" do
    test "returns 200 OK when database is connected", %{conn: conn} do
      conn = get(conn, ~p"/healthz")
      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert response["database"] == "connected"
    end
  end

  describe "GET /version" do
    test "returns version information", %{conn: conn} do
      conn = get(conn, ~p"/version")
      response = json_response(conn, 200)

      assert is_binary(response["sha"])
      assert is_binary(response["env"])
    end
  end
end
