defmodule Vereis.HealthTest do
  use Vereis.DataCase, async: true

  alias Vereis.Health

  describe "liveness/0" do
    test "always returns :ok" do
      assert Health.liveness() == :ok
    end
  end

  describe "readiness/0" do
    test "returns :ok when database is accessible" do
      assert Health.readiness() == :ok
    end
  end
end
