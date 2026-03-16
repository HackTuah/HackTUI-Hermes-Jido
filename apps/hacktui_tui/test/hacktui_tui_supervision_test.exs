defmodule HacktuiTui.SupervisionTest do
  use ExUnit.Case, async: false

  test "starts explicit TUI boundary supervisors" do
    assert {:ok, _started} = Application.ensure_all_started(:hacktui_tui)
    assert Process.whereis(HacktuiTui.Supervisor)
    assert Process.whereis(HacktuiTui.SessionSupervisor)
    assert Process.whereis(HacktuiTui.TaskSupervisor)
  end
end
