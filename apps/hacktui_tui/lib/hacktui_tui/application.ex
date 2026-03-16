defmodule HacktuiTui.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    HacktuiTui.Supervisor.start_link([])
  end
end
