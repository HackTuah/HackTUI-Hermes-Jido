defmodule HacktuiSensor.Supervisor do
  @moduledoc false
  use Supervisor

  alias HacktuiSensor.Forwarder

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      Forwarder,
      {DynamicSupervisor, strategy: :one_for_one, name: HacktuiSensor.CollectorsSupervisor},
      {Task.Supervisor, name: HacktuiSensor.TaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
