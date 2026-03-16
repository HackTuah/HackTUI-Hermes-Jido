defmodule HacktuiStoreTest do
  use ExUnit.Case, async: false

  test "starts its supervision tree with repo disabled by default" do
    assert {:ok, _started} = Application.ensure_all_started(:hacktui_store)
    assert Process.whereis(HacktuiStore.TaskSupervisor)
    refute Process.whereis(HacktuiStore.Repo)
  end

  test "declares implemented and planned record families honestly" do
    families = HacktuiStore.durable_record_families()
    planned = HacktuiStore.planned_record_families()

    assert :alerts in families
    assert :cases in families
    assert :audit_events in families
    refute :artifact_manifests in families
    assert :artifact_manifests in planned
  end
end
