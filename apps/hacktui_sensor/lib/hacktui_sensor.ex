defmodule HacktuiSensor do
  @moduledoc """
  Sensor runtime boundary metadata and collector orchestration.
  """

  alias HacktuiCore.Commands.AcceptObservation
  alias HacktuiSensor.Forwarder

  @collectors [:journald, :process_signals, :packet_capture]
  @default_process_interval_ms 5_000
  @default_journal_lines 10

  @spec collectors() :: [atom()]
  def collectors, do: @collectors

  @spec start_collectors() :: :ok
  def start_collectors do
    collector_specs()
    |> Enum.each(fn spec ->
      case DynamicSupervisor.start_child(HacktuiSensor.CollectorsSupervisor, spec) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        {:error, :already_present} -> :ok
      end
    end)

    :ok
  end

  defp collector_specs do
    [
      {HacktuiSensor.Collectors.Journald, journald_opts()},
      {HacktuiSensor.Collectors.ProcessSignals, process_signal_opts()},
      {HacktuiSensor.Collectors.Network, network_opts()}
    ]
  end

  defp network_opts do
    app_config = Application.get_env(:hacktui_sensor, __MODULE__, [])

    [
      enabled?: Keyword.get(app_config, :network_enabled, true),
      interface: Keyword.get(app_config, :network_interface, "any")
    ]
  end

  defp process_signal_opts do
    [
      interval_ms:
        Application.get_env(:hacktui_sensor, __MODULE__, [])
        |> Keyword.get(:process_signals_interval_ms, @default_process_interval_ms)
    ]
  end

  defp journald_opts do
    app_config = Application.get_env(:hacktui_sensor, __MODULE__, [])

    [
      enabled?: Keyword.get(app_config, :journald_enabled, true),
      lines: Keyword.get(app_config, :journald_lines, @default_journal_lines)
    ]
  end

  # --- Nested Collector Modules ---

  defmodule Collectors.ProcessSignals do
    @moduledoc false
    use GenServer

    @default_interval_ms 5_000

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts)
    end

    @impl true
    def init(opts) do
      state = %{
        interval_ms: Keyword.get(opts, :interval_ms, @default_interval_ms),
        host_identity: hostname(),
        source_node: node() |> to_string()
      }

      Process.send_after(self(), :collect, 0)
      {:ok, state}
    end

    @impl true
    def handle_info(:collect, state) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      payload = normalized_payload(state, now)

      command = %AcceptObservation{
        observation_id: unique_id("obs"),
        fingerprint: unique_id("fp"),
        source: "sensor.process_signals",
        summary: "Process signals heartbeat from #{state.host_identity}",
        raw_message: inspect(payload),
        severity: :low,
        confidence: 0.6,
        kind: "process_signals",
        payload: payload,
        metadata: %{
          collector: :process_signals,
          path: :live,
          severity: "info",
          occurred_at: DateTime.to_iso8601(now),
          observed_at: DateTime.to_iso8601(now),
          source_node: state.source_node,
          host_identity: state.host_identity
        },
        observed_at: now,
        received_at: now,
        actor: "hacktui_sensor",
        envelope_version: 1
      }

      _ = Forwarder.accept_observation(command)

      Process.send_after(self(), :collect, state.interval_ms)
      {:noreply, state}
    end

    defp normalized_payload(state, now) do
      message_queue_len = Process.info(self(), :message_queue_len) |> elem(1)
      reductions = Process.info(self(), :reductions) |> elem(1)
      pid_text = inspect(self())

      %{
        "summary" => "BEAM node health check | mq=#{message_queue_len} red=#{reductions}",
        "observed_at" => DateTime.to_iso8601(now),
        "node" => state.source_node,
        "host" => state.host_identity,
        "pid" => pid_text,
        "message_queue_len" => message_queue_len,
        "reductions" => reductions
      }
    end

    defp hostname do
      case :inet.gethostname() do
        {:ok, value} -> to_string(value)
        _ -> "unknown-host"
      end
    end

    defp unique_id(prefix) do
      "#{prefix}-#{System.unique_integer([:positive, :monotonic])}"
    end
  end

  defmodule Collectors.Journald do
    @moduledoc false
    use GenServer

    @journalctl_path System.find_executable("journalctl")

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts)
    end

    @impl true
    def init(opts) do
      state = %{
        enabled?: Keyword.get(opts, :enabled?, true),
        lines: Keyword.get(opts, :lines, 20),
        host_identity: hostname(),
        source_node: node() |> to_string(),
        port: nil,
        buffer: ""
      }

      send(self(), :boot)
      {:ok, state}
    end

    @impl true
    def handle_info(:boot, %{enabled?: false} = state), do: {:noreply, state}
    def handle_info(:boot, %{enabled?: true} = state), do: {:noreply, start_journal_stream(state)}

    @impl true
    def handle_info({_port, {:data, data}}, %{buffer: buffer} = state) when is_binary(data) do
      text = buffer <> data
      lines = String.split(text, "\n", trim: false)

      {complete_lines, next_buffer} =
        case lines do
          [] -> {[], ""}
          parts -> {Enum.drop(parts, -1), List.last(parts) || ""}
        end

      Enum.each(complete_lines, fn line ->
        line
        |> String.trim()
        |> maybe_emit_observation(state)
      end)

      {:noreply, %{state | buffer: next_buffer}}
    end

    def handle_info({_port, {:exit_status, _status}}, state) do
      Process.send_after(self(), :boot, 2_000)
      {:noreply, %{state | port: nil, buffer: ""}}
    end

    def handle_info(_msg, state), do: {:noreply, state}

    defp start_journal_stream(%{enabled?: true} = state) do
      cond do
        is_nil(@journalctl_path) ->
          state

        true ->
          args = [
            "--no-pager",
            "--output=short-iso",
            "--follow",
            "--lines=#{state.lines}"
          ]

          port =
            Port.open(
              {:spawn_executable, @journalctl_path},
              [:binary, :exit_status, :stderr_to_stdout, args: args]
            )

          %{state | port: port, buffer: ""}
      end
    end

    defp maybe_emit_observation("", _state), do: :ok

    defp maybe_emit_observation(line, state) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      {kind, summary, severity} = classify_line(line)

      command = %AcceptObservation{
        observation_id: unique_id("journal"),
        fingerprint: unique_id("fp"),
        source: "sensor.journald",
        kind: kind,
        summary: summary,
        raw_message: line,
        severity: severity,
        confidence: if(severity in ["high", "critical"], do: 0.9, else: 0.65),
        payload: %{
          "summary" => summary,
          "raw_message" => line,
          "severity" => severity,
          "host" => state.host_identity,
          "node" => state.source_node,
          "observed_at" => DateTime.to_iso8601(now)
        },
        metadata: %{
          collector: :journald,
          path: :live,
          occurred_at: DateTime.to_iso8601(now),
          observed_at: DateTime.to_iso8601(now),
          source_node: state.source_node,
          host_identity: state.host_identity,
          severity: severity
        },
        observed_at: now,
        received_at: now,
        actor: "hacktui_sensor",
        envelope_version: 1
      }

      _ = Forwarder.accept_observation(command)
      :ok
    end

    defp classify_line(line) do
      lower = String.downcase(line)

      cond do
        String.contains?(lower, "apparmor=\"denied\"") or
            String.contains?(lower, "audit: type=1400") ->
          {"journald.security", "apparmor/audit denial detected", "high"}

        String.contains?(lower, "ptrace") and String.contains?(lower, "denied") ->
          {"journald.security", "ptrace denied", "high"}

        String.contains?(lower, "sudo") and String.contains?(lower, "authentication failure") ->
          {"journald.auth", "sudo authentication failure", "high"}

        String.contains?(lower, "failed password") ->
          {"journald.auth", "failed password attempt", "medium"}

        String.contains?(lower, "segfault") ->
          {"journald.process", "process crash/segfault detected", "medium"}

        true ->
          {"journald", shorten(line, 120), "info"}
      end
    end

    defp hostname do
      case :inet.gethostname() do
        {:ok, value} -> to_string(value)
        _ -> "unknown-host"
      end
    end

    defp shorten(text, max_len) do
      text = to_string(text)

      if String.length(text) <= max_len do
        text
      else
        String.slice(text, 0, max_len - 1) <> "…"
      end
    end

    defp unique_id(prefix) do
      "#{prefix}-#{System.unique_integer([:positive, :monotonic])}"
    end
  end
end
