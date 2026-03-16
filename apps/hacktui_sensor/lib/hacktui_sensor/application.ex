defmodule HacktuiSensor.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    case HacktuiSensor.Supervisor.start_link([]) do
      {:ok, _pid} = started ->
        HacktuiSensor.start_collectors()
        started

      other ->
        other
    end
  end
end
