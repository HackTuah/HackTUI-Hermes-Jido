defmodule Hacktui.State do
  use GenServer

  # --- Client API ---

  # 1. Added input_mode and search_query to the state
  def start_link(_), do: 
    GenServer.start_link(__MODULE__, %{
      alerts: [], 
      logs: [], 
      domains: MapSet.new(), 
      threat_counts: %{},
      input_mode: false,
      search_query: ""
    }, name: __MODULE__)

  def get_state, do: GenServer.call(__MODULE__, :get_state)
  def add_alert(type, message), do: GenServer.cast(__MODULE__, {:add_alert, %{type: type, message: message}})
  def add_log(entry), do: GenServer.cast(__MODULE__, {:add_log, entry})
  def track_domain(domain), do: GenServer.cast(__MODULE__, {:track_domain, domain})
  def clear_alerts, do: GenServer.cast(__MODULE__, :clear_alerts)
  def track_suspicious(domain), do: GenServer.cast(__MODULE__, {:track_suspicious, domain})

  # 2. NEW: Input Mode API
  def toggle_input_mode, do: GenServer.cast(__MODULE__, :toggle_input)
  def update_search_query(char), do: GenServer.cast(__MODULE__, {:update_search, char})
  def clear_search_query, do: GenServer.cast(__MODULE__, :clear_search)

  # --- Server Callbacks ---

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:add_alert, alert}, state) do
    %Hacktui.Schema.Alert{}
    |> Hacktui.Schema.Alert.changeset(alert)
    |> Hacktui.Repo.insert()

    {:noreply, %{state | alerts: [alert | Enum.take(state.alerts, 19)]}}
  end

  @impl true
  def handle_cast({:add_log, entry}, state) do
    {:noreply, %{state | logs: [entry | Enum.take(state.logs, 49)]}}
  end

  @impl true
  def handle_cast({:track_domain, domain}, state) do
    {:noreply, %{state | domains: MapSet.put(state.domains, domain)}}
  end

  @impl true
  def handle_cast(:clear_alerts, state) do
    {:noreply, %{state | alerts: []}}
  end

  @impl true
  def handle_cast({:track_suspicious, domain}, state) do
    count = Map.get(state.threat_counts, domain, 0) + 1
    new_counts = Map.put(state.threat_counts, domain, count)

    cond do
      count == 1 ->
        Hacktui.State.add_alert("SUSPICIOUS DNS", "Initial lookup: #{domain}")
        Hacktui.Workers.Enricher.investigate(domain)
        
      count == 5 ->
        Hacktui.State.add_alert("CRITICAL BEACONING", "High frequency lookups (5+) to: #{domain}")
        Hacktui.State.add_log("[🚨 CRITICAL] Escalated threat level for #{domain} due to repetitive beaconing!")

      true ->
        :ok
    end

    {:noreply, %{state | threat_counts: new_counts}}
  end

  # 3. NEW: Input Mode Callbacks
  @impl true
  def handle_cast(:toggle_input, state) do
    {:noreply, %{state | input_mode: !state.input_mode}}
  end

  @impl true
  def handle_cast({:update_search, char}, state) do
    {:noreply, %{state | search_query: state.search_query <> char}}
  end

  @impl true
  def handle_cast(:clear_search, state) do
    {:noreply, %{state | search_query: "", input_mode: false}}
  end
end
