defmodule HacktuiCollab.CollabDbSmokeTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias HacktuiCollab.Health
  alias HacktuiCollab.TestSupport.Integration
  alias HacktuiHub.Health, as: HubHealth

  setup_all do
    Integration.require_db_env!()
    Application.put_env(:hacktui_collab, :enabled_providers, [:slack])
    Integration.start_repo!()
    Integration.migrate!()
    {:ok, _} = Application.ensure_all_started(:hacktui_hub)

    if Process.whereis(HacktuiCollab.Supervisor) do
      Application.stop(:hacktui_collab)
    end

    {:ok, _} = Application.ensure_all_started(:hacktui_collab)

    on_exit(fn ->
      Application.put_env(:hacktui_collab, :enabled_providers, [])
      Application.stop(:hacktui_collab)
      Application.stop(:hacktui_hub)
      Integration.stop_repo!()
    end)

    :ok
  end

  setup do
    HacktuiCollab.TestSupport.Integration.checkout!()
    HacktuiCollab.TestSupport.Integration.cleanup!()
    :ok
  end

  test "db-backed + collab mode reports explicit enabled and disabled boundaries" do
    collab = Health.status()
    hub = HubHealth.status()

    assert collab.mode == :enabled
    assert collab.enabled?
    assert collab.enabled_providers == [:slack]

    assert hub.store.mode == :db_backed
    assert hub.collab.mode == :enabled
    assert hub.agent.mode == :disabled
  end
end
