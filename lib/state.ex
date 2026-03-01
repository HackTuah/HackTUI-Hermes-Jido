defmodule Hacktui.State do
  use GenServer

  @type alert :: %{type: String.t(), message: String.t(), timestamp: DateTime.t()}
  @type t :: %{logs: [String.t()], alerts: [alert()], domains: MapSet.t(String.t())}

  def start_link(_) do
    # Added domains: MapSet.new() to track unique network destinations
    GenServer.start_link(__MODULE__, %{logs: [], alerts: [], domains: MapSet.new()}, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get)
  end

  def add_log(msg) do
    GenServer.cast(__MODULE__, {:add_log, msg})
  end

  def add_alert(type, msg) do
    GenServer.cast(__MODULE__, {:add_alert, type, msg})
  end

  def track_domain(domain) do
    GenServer.cast(__MODULE__, {:track_domain, domain})
  end

  def init(state), do: {:ok, state}

  def handle_call(:get, _from, state), do: {:reply, state, state}

  def handle_cast({:add_log, msg}, state) do
    {:noreply, %{state | logs: Enum.take([msg | state.logs], 50)}}
  end

  def handle_cast({:add_alert, type, msg}, state) do
    alert = %{type: type, message: msg, timestamp: DateTime.utc_now()}
    {:noreply, %{state | alerts: Enum.take([alert | state.alerts], 20)}}
  end

  def handle_cast({:track_domain, domain}, state) do
    # MapSet automatically prevents duplicate domains from being added
    new_domains = MapSet.put(state.domains, domain)
    {:noreply, %{state | domains: new_domains}}
  end
end
