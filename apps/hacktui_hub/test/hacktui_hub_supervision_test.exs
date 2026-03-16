defmodule HacktuiHub.SupervisionTest do
  use ExUnit.Case, async: false

  test "starts explicit boundary supervisors" do
    assert {:ok, _started} = Application.ensure_all_started(:hacktui_hub)

    assert Process.whereis(HacktuiHub.Registry)
    assert Process.whereis(HacktuiHub.TaskSupervisor)
    assert Process.whereis(HacktuiHub.IngestSupervisor)
    assert Process.whereis(HacktuiHub.DetectionSupervisor)
    assert Process.whereis(HacktuiHub.CaseworkSupervisor)
    assert Process.whereis(HacktuiHub.ResponseSupervisor)
    assert Process.whereis(HacktuiHub.PolicySupervisor)
    assert Process.whereis(HacktuiHub.AuditSupervisor)
  end
end
