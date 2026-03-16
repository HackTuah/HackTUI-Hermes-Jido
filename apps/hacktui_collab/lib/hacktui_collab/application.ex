defmodule HacktuiCollab.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info(
      "[hacktui_collab] enabled_providers=#{inspect(HacktuiCollab.enabled_providers())}"
    )

    HacktuiCollab.Supervisor.start_link([])
  end
end
