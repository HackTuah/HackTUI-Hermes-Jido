defmodule Hacktui.Workers.HermesBridge do
  @moduledoc """
  The bridge between the HackTUI SIEM and the Hermes AI Agent.
  Monitors the system state for critical alerts and triggers investigations.
  """
  use GenServer
  require Logger

  # --- Client API ---

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def trigger_investigation(type, msg) do
    GenServer.cast(__MODULE__, {:investigate, type, msg})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_) do
    case System.find_executable("hermes") do
      nil ->
        {:ok, %{investigations_count: 0, connected: false}}
      path ->
        Logger.info("[HERMES] ✅ Binary found at #{path}")
        Process.send_after(self(), :verify_connection, 1000)
        {:ok, %{investigations_count: 0, connected: false}}
    end
  end

  @impl true
  def handle_info(:verify_connection, state) do
    case System.cmd("hermes", ["--version"]) do
      {version, 0} ->
        version_trimmed = String.trim(version)
        Hacktui.State.add_log("[HERMES] 🤖 Agent Verified: #{version_trimmed}")
        {:noreply, %{state | connected: true}}
      _ ->
        {:noreply, %{state | connected: false}}
    end
  end

  # ✅ Fixed unused variable warnings by adding underscores
  @impl true
  def handle_cast({:investigate, _type, _msg}, %{connected: false} = state) do
    Hacktui.State.add_log("[HERMES] ❌ Cannot investigate. Agent is disconnected.")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:investigate, type, msg}, state) do
    Hacktui.State.add_log("[HERMES] 🧠 Agent triggered for: #{type}")
    Task.start(fn -> execute_hermes_analysis(type, msg) end)
    {:noreply, %{state | investigations_count: state.investigations_count + 1}}
  end

  defp execute_hermes_analysis(type, msg) do
    prompt = """
    CRITICAL SIEM ALERT DETECTED
    Type: #{type}
    Evidence: #{msg}
    
    INSTRUCTIONS:
    1. Use 'report_plan' to describe your investigation.
    2. Gather evidence from HackTUI logs.
    3. Call 'clear_plan' when finished.
    """

    case System.cmd("hermes", ["-c", prompt]) do
      {output, 0} ->
        Hacktui.State.add_log("[HERMES] ✅ Investigation complete.")
        summary = output |> String.split("\n") |> List.first() |> String.slice(0, 100)
        Hacktui.State.add_alert("AGENT REPORT", "Summary: #{summary}...")
        Hacktui.State.clear_planning_text()
      _ ->
        Hacktui.State.add_log("[HERMES] ❌ Agent execution failed.")
        Hacktui.State.clear_planning_text()
    end
  end
end
