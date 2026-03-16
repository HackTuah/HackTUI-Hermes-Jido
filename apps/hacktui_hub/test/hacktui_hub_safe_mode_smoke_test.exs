defmodule HacktuiHub.SafeModeSmokeTest do
  use ExUnit.Case, async: false

  alias HacktuiHub.Health

  test "safe no-repo mode keeps optional boundaries disabled" do
    assert %{hub: hub, store: store, collab: collab, agent: agent} = Health.status()

    assert hub.supervisor_started?
    assert store.mode == :safe_no_repo
    assert collab.mode == :disabled
    assert agent.mode == :disabled
  end
end
