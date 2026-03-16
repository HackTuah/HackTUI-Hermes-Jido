defmodule HacktuiHub.DetectionService do
  @moduledoc """
  Hub-facing service wrapper around pure alerting command handlers.
  """

  alias HacktuiCore.CommandHandlers.Alerting

  defdelegate create_alert(command, opts), to: Alerting, as: :handle
  defdelegate derive_alert(observation, opts), to: Alerting, as: :handle
  defdelegate transition_alert(alert, command, opts), to: Alerting, as: :handle
end
