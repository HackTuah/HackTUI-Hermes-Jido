defmodule Hacktui.Application do
  use Application

  def start(_type, _args) do
    children = [
      Hacktui.State,
      Hacktui.Workers.LogSentinel,
      Hacktui.Workers.NetScout,
      Hacktui.UI.Dashboard
    ]

    opts = [strategy: :one_for_one, name: Hacktui.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
