defmodule HacktuiStore.Alerts do
  @moduledoc """
  Ecto persistence flows for alert records and alert transitions.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias HacktuiCore.Aggregates.Alert, as: DomainAlert
  alias HacktuiCore.Events.{AlertCreated, AlertTransitioned}
  alias HacktuiStore.Schema.{Alert, AlertTransition}

  @spec persist_create(module(), DomainAlert.t(), AlertCreated.t()) ::
          HacktuiStore.transaction_result()
  def persist_create(repo, %DomainAlert{} = alert, %AlertCreated{} = event) do
    alert
    |> create_multi(event)
    |> repo.transaction()
  end

  @spec persist_transition(module(), DomainAlert.t(), AlertTransitioned.t()) ::
          HacktuiStore.transaction_result()
  def persist_transition(repo, %DomainAlert{} = alert, %AlertTransitioned{} = event) do
    alert
    |> transition_multi(event)
    |> repo.transaction()
  end

  @spec create_multi(DomainAlert.t(), AlertCreated.t()) :: Ecto.Multi.t()
  def create_multi(%DomainAlert{} = alert, %AlertCreated{} = event) do
    Multi.new()
    |> Multi.insert(:alert_insert, alert_changeset(alert, event))
  end

  @spec transition_multi(DomainAlert.t(), AlertTransitioned.t()) :: Ecto.Multi.t()
  def transition_multi(%DomainAlert{} = alert, %AlertTransitioned{} = event) do
    query = from(record in Alert, where: record.alert_id == ^alert.alert_id)

    Multi.new()
    |> Multi.update_all(
      :alert_state_update,
      query,
      set: [state: Atom.to_string(alert.state), updated_at: event.occurred_at]
    )
    |> Multi.insert(:alert_transition_insert, alert_transition_changeset(event))
  end

  defp alert_changeset(%DomainAlert{} = alert, %AlertCreated{} = event) do
    Alert.changeset(%Alert{}, %{
      id: Ecto.UUID.generate(),
      alert_id: alert.alert_id,
      title: alert.title,
      severity: Atom.to_string(alert.severity),
      state: Atom.to_string(alert.state),
      disposition: Atom.to_string(alert.disposition),
      metadata: %{
        observation_refs: alert.observation_refs,
        created_event_id: event.event_id
      }
    })
  end

  defp alert_transition_changeset(%AlertTransitioned{} = event) do
    AlertTransition.changeset(%AlertTransition{}, %{
      id: Ecto.UUID.generate(),
      alert_id: event.alert_id,
      from_state: Atom.to_string(event.from_state),
      to_state: Atom.to_string(event.to_state),
      reason: event.reason,
      actor_id: event.actor.id,
      occurred_at: event.occurred_at,
      metadata: %{
        event_id: event.event_id
      }
    })
  end
end
