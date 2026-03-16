defmodule HacktuiHub.Projectors.AlertProjector do
  @moduledoc """
  Projects alert-domain events into the operator-facing alerts read model.

  This keeps the dashboard query side simple:
    AlertCreated -> alerts table -> QueryService.alert_queue/1
  """

  use GenServer

  alias HacktuiCore.Events.AlertCreated
  alias HacktuiStore.{Repo, Schema.Alert}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @doc """
  Public entrypoint for projecting an alert event into the read model.
  """
  @spec project(AlertCreated.t()) :: {:ok, Alert.t()} | {:error, term()}
  def project(%AlertCreated{} = event) do
    GenServer.call(__MODULE__, {:project, event})
  end

  @impl true
  def handle_call({:project, %AlertCreated{} = event}, _from, state) do
    result = upsert_alert(event)
    {:reply, result, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, {:error, :unsupported_event}, state}
  end

  defp upsert_alert(%AlertCreated{} = event) do
    attrs = %{
      alert_id: event.alert_id,
      title: event.title,
      severity: normalize_severity(event.severity),
      state: "open",
      inserted_at: event.occurred_at,
      updated_at: event.occurred_at
    }

    case Repo.get_by(Alert, alert_id: event.alert_id) do
      nil ->
        %Alert{}
        |> Alert.changeset(attrs)
        |> Repo.insert()

      %Alert{} = existing ->
        existing
        |> Alert.changeset(%{
          title: attrs.title,
          severity: attrs.severity,
          state: attrs.state,
          updated_at: attrs.updated_at
        })
        |> Repo.update()
    end
  end

  defp normalize_severity(severity) when is_atom(severity),
    do: severity |> Atom.to_string() |> String.downcase()

  defp normalize_severity(severity) when is_binary(severity),
    do: String.downcase(severity)

  defp normalize_severity(_), do: "info"
end
