defmodule HacktuiHub.ThreatIntel.Indexer do
  @moduledoc """
  Memory-safe Threat Intel Index. 
  Loads data dynamically at runtime to completely prevent 'literal_alloc' compiler crashes.
  """
  use GenServer
  require Logger

  @table_name :threat_intel_keywords

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def lookup(text) when is_binary(text) do
    text_lower = String.downcase(text)
    
    :ets.safe_fixtable(@table_name, true)
    result = :ets.foldl(fn {keyword, desc}, acc ->
      if acc == nil and String.contains?(text_lower, String.downcase(keyword)), do: {keyword, desc}, else: acc
    end, nil, @table_name)
    :ets.safe_fixtable(@table_name, false)
    
    result
  end

  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    send(self(), :load_data)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:load_data, state) do
    # We use a small, safe default list here. 
    # Do NOT let the agent hardcode the 50,000 keywords in this file again!
    defaults = [
      {"mimikatz", "Credential Theft Detected"},
      {"cobaltstrike", "C2 Beaconing Signature"},
      {"apparmor=\"denied\"", "Process Security Violation"},
      {"nmap", "Network Scanning Activity"}
    ]
    
    Enum.each(defaults, fn {k, v} -> :ets.insert(@table_name, {k, v}) end)
    Logger.info("[hacktui_intel] Safe ETS indexer loaded to prevent memory crashes.")
    {:noreply, state}
  end
end
