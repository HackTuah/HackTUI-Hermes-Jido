defmodule HacktuiHub.IngestService do
  @moduledoc """
  Hub-facing service wrapper around the pure ingest command handler.
  Fixed to route live telemetry to the GenServer IngestBuffer safely, 
  preventing fatal :persistent_term memory allocator crashes.
  """

  alias HacktuiCore.CommandHandlers.Ingest
  alias HacktuiCore.Commands.AcceptObservation
  alias HacktuiCore.Events.ObservationAccepted
  alias HacktuiHub.ThreatIntel.Enricher
  alias HacktuiHub.IngestBuffer

  @spec accept_observation(AcceptObservation.t(), keyword()) :: term()
  def accept_observation(%AcceptObservation{} = command, opts) do
    command = enrich_command(command)
    opts = ingest_opts(command, opts)

    case Ingest.handle(command, opts) do
      {:ok, %ObservationAccepted{} = accepted} ->
        accepted = enrich_accepted(accepted, command)
        
        # Safely route the live stream to the GenServer Ring Buffer
        # instead of blowing out the literal memory allocator.
        ensure_buffer_started()
        try do
          IngestBuffer.insert(accepted)
        catch
          :exit, _ -> :ok
        end

        {:ok, accepted}

      other ->
        other
    end
  end

  @spec recent_observations() :: [ObservationAccepted.t()]
  def recent_observations do
    ensure_buffer_started()
    try do
      IngestBuffer.get_recent()
    catch
      :exit, _ -> []
    end
  end

  @spec reset_recent_observations() :: :ok
  def reset_recent_observations do
    ensure_buffer_started()
    try do
      IngestBuffer.clear()
    catch
      :exit, _ -> :ok
    end
    :ok
  end

  defp ensure_buffer_started do
    if is_nil(Process.whereis(IngestBuffer)) do
      # CRITICAL FIX: Pass the properly formatted Map state %{limit: 100, items: []} 
      # instead of a keyword list [limit: 100] so handle_cast matches correctly!
      case GenServer.start(IngestBuffer, %{limit: 100, items: []}, name: IngestBuffer) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
        _ -> :ok
      end
    end
  end

  defp ingest_opts(%AcceptObservation{} = command, opts) do
    now = command.received_at || command.observed_at || DateTime.utc_now()

    opts
    |> Keyword.put_new(:event_id, "ingest-#{command.observation_id}")
    |> Keyword.put_new(:accepted_at, now)
  end

  defp enrich_accepted(%ObservationAccepted{} = accepted, %AcceptObservation{} = command) do
    %ObservationAccepted{
      accepted
      | kind: command.kind,
        payload: command.payload,
        metadata: command.metadata
    }
  end

  defp enrich_command(%AcceptObservation{} = command) do
    # Create a safe, compliant struct for the Enricher to avoid compiler warnings
    dummy_obs = %ObservationAccepted{
      event_id: "enrich-#{command.observation_id}",
      observation_id: command.observation_id,
      source: command.source || "unknown",
      kind: command.kind || "unknown",
      payload: command.payload || %{},
      metadata: command.metadata || %{},
      accepted_at: command.received_at || command.observed_at || DateTime.utc_now(),
      actor: command.actor || "system"
    }

    enriched_obs = Enricher.enrich(dummy_obs)
    apply_enriched_command(enriched_obs, command)
  rescue
    _ -> command
  end

  defp apply_enriched_command(%ObservationAccepted{} = enriched, %AcceptObservation{} = command) do
    metadata = Map.get(enriched, :metadata, %{}) || %{}

    severity =
      metadata
      |> Map.get(:threat_context, %{})
      |> case do
         m when is_map(m) -> Map.get(m, :severity)
         _ -> nil
      end
      |> case do
        nil -> Map.get(command, :severity)
        threat_severity -> threat_severity
      end

    %AcceptObservation{command | metadata: metadata, severity: severity}
  end

  defp apply_enriched_command(_, %AcceptObservation{} = command), do: command
end
