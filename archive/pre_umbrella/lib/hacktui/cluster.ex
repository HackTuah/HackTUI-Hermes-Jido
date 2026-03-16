defmodule Hacktui.Cluster do
  @moduledoc """
  Hardened Cluster Manager.
  Uses active polling and manual handshake forcing to ensure connectivity.
  """
  use GenServer
  require Logger

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(_) do
    # Retrieve Hub target from environment
    hub_addr = System.get_env("HUB_ADDR") || "hub@127.0.0.1"
    
    # Start the heartbeat/reconnection loop
    :timer.send_interval(5000, {:attempt_connect, String.to_atom(hub_addr)})
    
    {:ok, %{hub_target: hub_addr, status: :disconnected}}
  end

  @impl true
  def handle_info({:attempt_connect, hub_atom}, state) do
    if hub_atom == node() do
      # We are the hub, just monitor for incoming connections
      {:noreply, %{state | status: :hub_active}}
    else
      # Attempt manual handshake
      case Node.connect(hub_atom) do
        true ->
          if state.status != :connected do
            Logger.info("[CLUSTER] Successfully established link to Hub: #{hub_atom}")
          end
          {:noreply, %{state | status: :connected}}
        _ ->
          # Silent retry to keep logs clean in TUI
          {:noreply, %{state | status: :disconnected}}
      end
    end
  end
end
