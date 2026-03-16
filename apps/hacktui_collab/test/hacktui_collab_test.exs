defmodule HacktuiCollabTest do
  use ExUnit.Case, async: false

  test "starts its supervision tree in disabled-by-default mode" do
    assert {:ok, _started} = Application.ensure_all_started(:hacktui_collab)
    assert Process.whereis(HacktuiCollab.Supervisor)
    refute Process.whereis(HacktuiCollab.TaskSupervisor)
  end

  test "scopes collaboration to supported providers" do
    assert HacktuiCollab.providers() == [:slack]
    refute HacktuiCollab.enabled?()
  end
end
