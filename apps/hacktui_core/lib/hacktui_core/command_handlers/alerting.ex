defmodule HacktuiCore.CommandHandlers.Alerting do
  @moduledoc """
  Pure command handling for alert creation and state transitions.
  """

  alias HacktuiCore.Aggregates.Alert
  alias HacktuiCore.Commands.{CreateAlert, TransitionAlert}
  alias HacktuiCore.Events.ObservationAccepted

  @spec handle(CreateAlert.t(), keyword()) :: {:ok, Alert.t(), struct()}
  def handle(%CreateAlert{} = command, opts), do: Alert.create(command, opts)

  @spec handle(ObservationAccepted.t(), keyword()) :: {:ok, Alert.t(), struct()}
  def handle(%ObservationAccepted{} = accepted, opts) do
    payload = accepted.payload || %{}

    command = %CreateAlert{
      alert_id: Map.fetch!(payload, "alert_id"),
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

  defp derive_title(_payload), do: "Replay-derived alert"

  defp derive_severity(%{"severity" => severity}) when is_binary(severity) do
    severity
    |> String.downcase()
    |> String.to_existing_atom()
  rescue
    ArgumentError -> :unknown
  end

  defp derive_severity(%{severity: severity}) when is_atom(severity), do: severity
  defp derive_severity(_payload), do: :unknown
end
