defmodule HacktuiHub.HealthTest do
  use ExUnit.Case, async: false

  alias HacktuiHub.Health

  test "aggregates boundary health status" do
    status = Health.status()

    assert Map.has_key?(status, :store)
    assert Map.has_key?(status, :collab)
    assert Map.has_key?(status, :agent)
    assert Map.has_key?(status, :hub)
  end
end
