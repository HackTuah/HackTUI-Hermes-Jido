defmodule HacktuiHubTest do
  use ExUnit.Case, async: false

  test "starts hub supervision primitives" do
    assert {:ok, _started} = Application.ensure_all_started(:hacktui_hub)
    assert Process.whereis(HacktuiHub.Registry)
    assert Process.whereis(HacktuiHub.TaskSupervisor)
  end

  test "declares its public runtime surfaces" do
    surfaces = HacktuiHub.public_surfaces()

    assert :sensor_ingest in surfaces
    assert :tui in surfaces
    assert :agent in surfaces
  end
end
