defmodule Mix.Tasks.Hacktui.Tui do
  use Mix.Task

  @shortdoc "Launch the persistent bounded HackTUI terminal app"

  def run(_args) do
    ensure_runtime_started()
    apply(HacktuiTui, :run_live_dashboard, [])
  end

  defp ensure_runtime_started do
    Application.put_env(:hacktui_store, :start_repo, true)

    {:ok, _} = Application.ensure_all_started(:hacktui_store)
    {:ok, _} = Application.ensure_all_started(:hacktui_hub)
    {:ok, _} = Application.ensure_all_started(:hacktui_agent)
    {:ok, _} = Application.ensure_all_started(:hacktui_sensor)
    {:ok, _} = Application.ensure_all_started(:hacktui_tui)

    :ok
  end
end
