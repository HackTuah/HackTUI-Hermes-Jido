defmodule HacktuiStore.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info(
      "[hacktui_store] start_repo=#{Application.get_env(:hacktui_store, :start_repo, false)}"
    )

    HacktuiStore.Supervisor.start_link([])
  end
end
