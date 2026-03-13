defmodule HacktuiHub.HubRestartSmokeTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias HacktuiHub.Health
  alias HacktuiHub.TestSupport.Integration

  setup_all do
    Integration.require_db_env!()
    Integration.start_repo!()
    Integration.migrate!()

    on_exit(fn ->
      if Process.whereis(HacktuiHub.Supervisor), do: Application.stop(:hacktui_hub)
      Integration.stop_repo!()
    end)

    :ok
  end

  setup do
    Integration.checkout!()
    :ok
  end

  test "db-backed hub mode can start, stop, and start again cleanly" do
    {:ok, _} = Application.ensure_all_started(:hacktui_hub)
    assert Health.status().store.mode == :db_backed
    assert Health.status().hub.supervisor_started?

    :ok = Application.stop(:hacktui_hub)
    refute Process.whereis(HacktuiHub.Supervisor)

    {:ok, _} = Application.ensure_all_started(:hacktui_hub)
    assert Health.status().store.mode == :db_backed
    assert Health.status().hub.supervisor_started?
  end
end
