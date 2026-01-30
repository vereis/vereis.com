defmodule Vereis.ServiceTest do
  use Vereis.DataCase, async: true

  alias Vereis.Service

  describe "get/0" do
    test "returns a Service struct with all fields populated" do
      service = Service.get()

      assert %Service{} = service
      assert service.id == "service:api"
      assert is_binary(service.sha)
      assert is_binary(service.env)
      assert is_boolean(service.liveness)
      assert is_boolean(service.readiness)
    end
  end

  describe "liveness?/0" do
    test "always returns true" do
      assert Service.liveness?() == true
    end
  end

  describe "readiness?/0" do
    test "returns true when database is accessible" do
      assert Service.readiness?() == true
    end
  end

  describe "version/0" do
    test "returns a git SHA or release SHA" do
      assert is_binary(Service.version())
    end
  end

  describe "env/0" do
    test "returns the environment as a string" do
      env = Service.env()
      assert is_binary(env)
      assert env in ["dev", "test", "prod", "development", "staging", "production"]
    end
  end
end
