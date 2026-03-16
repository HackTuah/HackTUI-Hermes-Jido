defmodule HacktuiAgent.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("[hacktui_agent] enabled_backends=#{inspect(HacktuiAgent.enabled_backends())}")
    HacktuiAgent.Supervisor.start_link([])
  end
end
