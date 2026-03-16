defmodule HacktuiStore.StartupModesTest do
  use ExUnit.Case, async: false

  alias HacktuiStore.Health

  setup do
    previous = Application.get_env(:hacktui_store, :start_repo)

    on_exit(fn ->
      Application.put_env(:hacktui_store, :start_repo, previous)
    end)

    :ok
  end

  test "reports safe no-repo mode by default" do
    Application.put_env(:hacktui_store, :start_repo, false)

    assert %{mode: :safe_no_repo, repo_enabled?: false, repo_started?: false} = Health.status()
  end

  test "reports degraded mode when repo startup is enabled but the repo is not started" do
    Application.put_env(:hacktui_store, :start_repo, true)

    assert %{
             mode: {:degraded, :repo_not_started},
             repo_enabled?: true,
             repo_started?: false,
             repo_connectivity: :repo_not_started
           } = Health.status()
  end

  test "supervisor child list includes repo only when enabled" do
    Application.put_env(:hacktui_store, :start_repo, false)
    {:ok, {_flags, children}} = HacktuiStore.Supervisor.init([])
    refute Enum.any?(children, &match?(%{id: HacktuiStore.Repo}, &1))

    Application.put_env(:hacktui_store, :start_repo, true)
    {:ok, {_flags, children}} = HacktuiStore.Supervisor.init([])
    assert Enum.any?(children, &match?(%{id: HacktuiStore.Repo}, &1))
  end
end
