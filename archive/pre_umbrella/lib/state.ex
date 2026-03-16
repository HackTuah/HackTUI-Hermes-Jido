defmodule Hacktui.State do
  @moduledoc """
  Optimized State GenServer for High-Throughput.
  Implements non-blocking persistence and mailbox optimization.
  Updated with Hermes "Thinking" support and active bridge triggers.
  """
  use GenServer

  # --- Client API ---

  def start_link(_), do: 
    GenServer.start_link(__MODULE__, %{
      alerts: [], 
      logs: [], 
      domains: MapSet.new(), 
      threat_counts: %{},
      intel_map: %{},
      planning_text: nil, # ✅ Capture Hermes reasoning for the Dashboard
      input_mode: false,
      search_query: "",
      metrics: %{eps: 0, last_tick_count: 0, total_received: 0}
    }, name: __MODULE__)

  def get_state, do: GenServer.call(__MODULE__, :get_state)
  
  # Telemetry API
  def add_alert(type, message), do: GenServer.cast(__MODULE__, {:add_alert, type, message})
  def add_log(entry), do: GenServer.cast(__MODULE__, {:add_log, entry})
  def track_domain(domain), do: GenServer.cast(__MODULE__, {:track_domain, domain})
  def clear_alerts, do: GenServer.cast(__MODULE__, :clear_alerts)
  def track_suspicious(domain), do: GenServer.cast(__MODULE__, {:track_suspicious, domain})
  def add_intel(domain, data), do: GenServer.cast(__MODULE__, {:add_intel, domain, data})

  # ✅ Hermes Logic API
  def set_planning_text(text), do: GenServer.cast(__MODULE__, {:set_planning_text, text})
  def clear_planning_text, do: GenServer.cast(__MODULE__, {:set_planning_text, nil})

  # UI Control API
  def toggle_input_mode, do: GenServer.cast(__MODULE__, :toggle_input)
  def update_search_query(char), do: GenServer.cast(__MODULE__, {:update_search, char})
  def clear_search_query, do: GenServer.cast(__MODULE__, :clear_search)

  # --- Server Callbacks ---

  @impl true
  def init(state) do
    :timer.send_interval(1000, :calculate_metrics)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:set_planning_text, text}, state) do
    {:noreply, %{state | planning_text: text}}
  end

  @impl true
  def handle_cast({:add_alert, type, message}, state) do
    alert_map = %{type: type, message: message}

    if Process.whereis(Hacktui.Repo) do
      Task.start(fn ->
        %Hacktui.Schema.Alert{}
        |> Hacktui.Schema.Alert.changeset(alert_map)
        |> Hacktui.Repo.insert()
      end)
    end

    {:noreply, %{state |
      alerts: [alert_map | Enum.take(state.alerts, 19)],
      metrics: Map.update!(state.metrics, :total_received, &(&1 + 1))
    }}
  end

  @impl true
  def handle_cast({:add_log, entry}, state) do
    {:noreply, %{state | 
      logs: [entry | Enum.take(state.logs, 49)],
      metrics: Map.update!(state.metrics, :total_received, &(&1 + 1))
    }}
  end

  @impl true
  def handle_cast({:track_domain, domain}, state) do
    {:noreply, %{state | domains: MapSet.put(state.domains, domain)}}
  end

  @impl true
  def handle_cast(:clear_alerts, state), do: {:noreply, %{state | alerts: []}}

  @impl true
  def handle_cast({:track_suspicious, domain}, state) do
    count = Map.get(state.threat_counts, domain, 0) + 1
    new_counts = Map.put(state.threat_counts, domain, count)

    # Process threat level logic
    Task.start(fn -> process_threat_level(domain, count) end)

    {:noreply, %{state | threat_counts: new_counts}}
  end

  @impl true
  def handle_cast({:add_intel, domain, data}, state) do
    {:noreply, %{state | intel_map: Map.put(state.intel_map, domain, data)}}
  end

  @impl true
  def handle_cast(:toggle_input, state), do: {:noreply, %{state | input_mode: !state.input_mode}}
  @impl true
  def handle_cast({:update_search, char}, state), do: {:noreply, %{state | search_query: state.search_query <> char}}
  @impl true
  def handle_cast(:clear_search, state), do: {:noreply, %{state | search_query: "", input_mode: false}}

  @impl true
  def handle_info(:calculate_metrics, state) do
    total = state.metrics.total_received
    eps = total - state.metrics.last_tick_count
    {:noreply, %{state | metrics: %{state.metrics | eps: eps, last_tick_count: total}}}
  end

  # --- Private Helpers ---

  defp process_threat_level(domain, 1) do
    add_alert("SUSPICIOUS DNS", "Initial lookup: #{domain}")
    Hacktui.Workers.Enricher.investigate(domain)
  end

  defp process_threat_level(domain, 5) do
    add_alert("CRITICAL BEACONING", "High frequency (5+) to: #{domain}")
    add_log("[🚨 CRITICAL] Escalated threat level for #{domain}")
    
    # ✅ Trigger the AI Agent Bridge
    # This calls the hermes binary with the forensics prompt
    Hacktui.Workers.HermesBridge.trigger_investigation("CRITICAL BEACONING", "Domain: #{domain}")
  end

  defp process_threat_level(_domain, _count), do: :ok
end
