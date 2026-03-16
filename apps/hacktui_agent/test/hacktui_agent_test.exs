defmodule HacktuiAgentTest do
  use ExUnit.Case, async: false

  test "starts its supervision tree in disabled-by-default mode" do
    assert {:ok, _started} = Application.ensure_all_started(:hacktui_agent)
    assert Process.whereis(HacktuiAgent.Supervisor)
    refute Process.whereis(HacktuiAgent.TaskSupervisor)
  end

  test "lists the bounded agent roles" do
    assert :triage in HacktuiAgent.roles()
    assert :runbook in HacktuiAgent.roles()
    refute HacktuiAgent.enabled?()
  end
end
