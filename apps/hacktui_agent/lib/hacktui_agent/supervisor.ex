defmodule HacktuiAgent.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children =
      if HacktuiAgent.enabled?() do
        [{Task.Supervisor, name: HacktuiAgent.TaskSupervisor}] ++ maybe_jido_child()
      else
        []
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp maybe_jido_child do
    if HacktuiAgent.backend_enabled?(:jido) do
      [HacktuiAgent.Jido]
    else
      []
    end
  end
end
