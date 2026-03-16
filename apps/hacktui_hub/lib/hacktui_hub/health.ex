defmodule HacktuiHub.Health do
  @moduledoc """
  Aggregates top-level boundary health into a single hub-facing snapshot.
  """

  @spec status() :: map()
  def status do
    hub = %{
      supervisor_started?: Process.whereis(HacktuiHub.Supervisor) != nil,
      registry_started?: Process.whereis(HacktuiHub.Registry) != nil,
      task_supervisor_started?: Process.whereis(HacktuiHub.TaskSupervisor) != nil
    }

    store = substatus(HacktuiStore.Health)
    collab = substatus(Elixir.HacktuiCollab.Health)
    agent = substatus(Elixir.HacktuiAgent.Health)

    %{
      summary: summarize(hub, store, collab, agent),
      ready?: ready?(hub, store, collab, agent),
      hub: hub,
      store: store,
      collab: collab,
      agent: agent
    }
  end

  defp summarize(hub, store, collab, agent) do
    [
      "hub=" <> summary_value(hub_ready?(hub)),
      "store=" <> summarize_mode(store),
      "collab=" <> summarize_mode(collab),
      "agent=" <> summarize_mode(agent)
    ]
    |> Enum.join(" ")
  end

  defp ready?(hub, store, collab, agent) do
    hub_ready?(hub) and component_ready?(store) and component_ready?(collab) and component_ready?(agent)
  end

  defp component_ready?(%{mode: :safe_no_repo}), do: true
  defp component_ready?(%{mode: :db_backed}), do: true
  defp component_ready?(%{mode: {:degraded, _reason}}), do: false
  defp component_ready?(%{mode: :unavailable}), do: false
  defp component_ready?(%{} = status), do: map_size(status) > 0
  defp component_ready?(_), do: false

  defp hub_ready?(hub) do
    Enum.all?(hub, fn {_key, value} -> value end)
  end

  defp summarize_mode(%{mode: {:degraded, reason}}), do: "degraded:" <> summarize_reason(reason)
  defp summarize_mode(%{mode: mode}), do: to_string(mode)
  defp summarize_mode(%{} = status), do: if(map_size(status) > 0, do: "present", else: "empty")
  defp summarize_mode(_), do: "unknown"

  defp summarize_reason({:error, reason}), do: normalize_reason(reason)
  defp summarize_reason(reason), do: normalize_reason(reason)

  defp normalize_reason(reason) when is_binary(reason), do: reason
  defp normalize_reason(reason), do: inspect(reason)

  defp summary_value(true), do: "up"
  defp summary_value(false), do: "down"

  defp substatus(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :status, 0) do
      apply(module, :status, [])
    else
      %{mode: :unavailable}
    end
  end
end
