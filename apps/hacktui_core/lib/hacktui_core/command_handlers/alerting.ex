defmodule HacktuiCore.CommandHandlers.Alerting do
  @moduledoc """
  Pure command handling for alert creation and state transitions.
  """

  alias HacktuiCore.Aggregates.Alert
  alias HacktuiCore.Commands.{CreateAlert, TransitionAlert}
  alias HacktuiCore.Detection
  alias HacktuiCore.Events.ObservationAccepted

  @spec handle(CreateAlert.t(), keyword()) :: {:ok, Alert.t(), struct()}
  def handle(%CreateAlert{} = command, opts), do: Alert.create(command, opts)

  @spec handle(ObservationAccepted.t(), keyword()) :: {:ok, Alert.t(), struct()}
  def handle(%ObservationAccepted{} = accepted, opts) do
    payload = accepted.payload || %{}

    command = %CreateAlert{
      # Derived when the payload carries no alert_id. This previously used Map.fetch!/2,
      # which raised KeyError on every live observation -- no sensor payload has that key,
      # only replay fixtures do.
      alert_id: Detection.alert_id_for(accepted),
      title: derive_title(payload),
      severity: derive_severity(payload),
      observation_refs: [accepted.observation_id],
      actor: accepted.actor
    }

    alert_opts =
      opts
      |> Keyword.put_new(:event_id, "derived-#{accepted.event_id}")
      |> Keyword.put_new(:occurred_at, accepted.accepted_at)

    Alert.create(command, alert_opts)
  end

  @spec handle(Alert.t(), TransitionAlert.t(), keyword()) ::
          {:ok, Alert.t(), struct()} | {:error, term()}
  def handle(%Alert{} = alert, %TransitionAlert{} = command, opts),
    do: Alert.transition(alert, command, opts)

  defp derive_title(%{"indicator" => indicator}) when is_binary(indicator),
    do: "Replay-derived alert for #{indicator}"

  defp derive_title(%{"summary" => summary}) when is_binary(summary) and summary != "",
    do: summary

  defp derive_title(%{summary: summary}) when is_binary(summary) and summary != "",
    do: summary

  defp derive_title(_payload), do: "Observation-derived alert"

  defp derive_severity(payload), do: Detection.severity_of(payload)
end
