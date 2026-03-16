defmodule HacktuiTuiTest do
  use ExUnit.Case, async: false

  test "starts its supervision tree" do
    assert {:ok, _started} = Application.ensure_all_started(:hacktui_tui)
    assert Process.whereis(HacktuiTui.TaskSupervisor)
  end

  test "lists the primary workflow areas" do
    areas = HacktuiTui.workflow_areas()

    assert :alert_queue in areas
    assert :approval_inbox in areas
    assert :command_palette in areas
  end
end
