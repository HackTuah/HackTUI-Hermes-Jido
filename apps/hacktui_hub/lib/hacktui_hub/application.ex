defmodule HacktuiHub.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    HacktuiHub.Supervisor.start_link([])
  end
end
