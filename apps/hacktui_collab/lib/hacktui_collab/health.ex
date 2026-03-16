defmodule HacktuiCollab.Health do
  @moduledoc """
  Reports the current collaboration runtime mode and basic health facts.
  """

  @spec status() :: map()
  def status do
    providers = HacktuiCollab.enabled_providers()

    %{
      mode: if(providers == [], do: :disabled, else: :enabled),
      enabled?: providers != [],
      enabled_providers: providers,
      supervisor_started?: Process.whereis(HacktuiCollab.Supervisor) != nil,
      task_supervisor_started?: Process.whereis(HacktuiCollab.TaskSupervisor) != nil
    }
  end
end
