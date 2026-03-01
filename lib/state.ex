defmodule Hacktui.State do
  use GenServer

  # --- Client API ---

  # 1. Added threat_counts to the initial state memory
  def start_link(_), do: 
    GenServer.start_link(__MODULE__, %{alerts: [], logs: [], domains: MapSet.new(), threat_counts: %{}}, name: __MODULE__)

  def get_state, do: GenServer.call(__MODULE__, :get_state)

  def add_alert(type, message), do: GenServer.cast(__MODULE__, {:add_alert, %{type: type, message: message}})

  def add_log(entry), do: GenServer.cast(__MODULE__, {:add_log, entry})

  def track_domain(domain), do: GenServer.cast(__MODULE__, {:track_domain, domain})

  def clear_alerts, do: GenServer.cast(__MODULE__, :clear_alerts)

  # 2. NEW: The Pattern Recognition API
  def track_suspicious(domain), do: GenServer.cast(__MODULE__, {:track_suspicious, domain})

  # --- Server Callbacks ---

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:add_alert, alert}, state) do
    # Save to PostgreSQL
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

  # 3. NEW: The Correlation Engine Logic
  @impl true
  def handle_cast({:track_suspicious, domain}, state) do
    # Increment the counter for this specific domain
    count = Map.get(state.threat_counts, domain, 0) + 1
    new_counts = Map.put(state.threat_counts, domain, count)

    cond do
      count == 1 ->
        # First offense: Standard alert and trigger background investigation
        Hacktui.State.add_alert("SUSPICIOUS DNS", "Initial lookup: #{domain}")
        Hacktui.Workers.Enricher.investigate(domain)
        
      count == 5 ->
        # Fifth offense: Escalate to a CRITICAL alert (Malware beaconing behavior)
        Hacktui.State.add_alert("CRITICAL BEACONING", "High frequency lookups (5+) to: #{domain}")
        Hacktui.State.add_log("[🚨 CRITICAL] Escalated threat level for #{domain} due to repetitive beaconing!")

      true ->
        # Do nothing on counts 2, 3, 4, 6, etc. to prevent alert fatigue!
        :ok
    end

    {:noreply, %{state | threat_counts: new_counts}}
  end
end
