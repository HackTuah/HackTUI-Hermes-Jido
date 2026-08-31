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

  describe "slice 03: processes that were previously unsupervised" do
    setup do
      {:ok, _} = Application.ensure_all_started(:hacktui_hub)
      :ok
    end

    test "IngestBuffer is supervised, not lazily spawned" do
      pid = Process.whereis(HacktuiHub.IngestBuffer)

      assert is_pid(pid)
      assert {:links, links} = Process.info(pid, :links)
      assert links != [], "an unsupervised GenServer.start/3 process would have no links"
    end

    test "the threat-intel ETS table exists at boot" do
      assert Process.whereis(HacktuiHub.ThreatIntel.Indexer)

      refute :ets.whereis(:threat_intel_keywords) == :undefined,
             "created in Indexer.init/1; unsupervised, it never existed"
    end

    test "IngestBuffer is restarted by its supervisor after a crash" do
      pid = Process.whereis(HacktuiHub.IngestBuffer)
      ref = Process.monitor(pid)

      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 2_000
      Process.sleep(100)

      new_pid = Process.whereis(HacktuiHub.IngestBuffer)
      assert is_pid(new_pid)
      refute new_pid == pid
    end
  end
end
