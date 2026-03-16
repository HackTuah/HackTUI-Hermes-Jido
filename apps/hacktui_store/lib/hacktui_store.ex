defmodule HacktuiStore do
  @moduledoc """
  Persistence boundary metadata and shared types for HackTUI durable records.
  """

  @implemented_record_families [
    :alerts,
    :alert_transitions,
    :cases,
    :case_timeline_entries,
    :action_requests,
    :audit_events
  ]

  @planned_record_families [
    :sensor_registrations,
    :actor_identities,
    :artifact_manifests,
    :export_bundles,
    :approvals,
    :action_executions,
    :notification_deliveries,
    :agent_runs
  ]

  @typedoc "Successful Ecto.Multi changes map keyed by operation name."
  @type transaction_changes :: %{optional(Ecto.Multi.name()) => term()}

  @typedoc "Result shape returned by Repo.transaction/1 when executing an Ecto.Multi."
  @type transaction_result ::
          {:ok, transaction_changes()}
          | {:error, Ecto.Multi.name(), term(), transaction_changes()}

  @spec durable_record_families() :: [atom()]
  def durable_record_families, do: @implemented_record_families

  @spec planned_record_families() :: [atom()]
  def planned_record_families, do: @planned_record_families
end
