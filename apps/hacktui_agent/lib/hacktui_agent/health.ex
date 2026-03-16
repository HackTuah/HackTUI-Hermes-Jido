defmodule HacktuiAgent.Health do
  @moduledoc """
  Reports the current agent runtime mode and basic health facts.
  """

  @spec status() :: map()
  def status do
    backends = HacktuiAgent.enabled_backends()
    jido_enabled? = HacktuiAgent.backend_enabled?(:jido)

    %{
      mode: if(jido_enabled?, do: :jido_enabled, else: :disabled),
      enabled?: backends != [],
      enabled_backends: backends,
      jido_enabled?: jido_enabled?,
      supervisor_started?: Process.whereis(HacktuiAgent.Supervisor) != nil,
      task_supervisor_started?: Process.whereis(HacktuiAgent.TaskSupervisor) != nil,
      jido_instance_started?: jido_started?()
    }
  end

  defp jido_started? do
    try do
      Jido.agent_supervisor_name(HacktuiAgent.Jido)
      |> Process.whereis()
      |> Kernel.!=(nil)
    rescue
      _ -> false
    end
  end
end
