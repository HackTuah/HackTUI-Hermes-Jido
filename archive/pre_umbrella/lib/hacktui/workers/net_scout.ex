defmodule Hacktui.Workers.NetScout do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    executable = System.find_executable("tcpdump")
    port = Port.open({:spawn_executable, executable}, [
      :binary, :stream, :line, :stderr_to_stdout,
      args: ["-l", "-n", "-i", "any", "udp", "port", "53"]
    ])
    {:ok, %{port: port}}
  end

  def handle_info({_port, {:data, {:eol, line}}}, state) do
    if String.contains?(line, [" A? ", " AAAA? "]) do
      domain = parse_domain(line)
      process_dns(domain)
    end
    {:noreply, state}
  end

  defp parse_domain(line) do
    line 
    |> String.split([" A? ", " AAAA? "]) 
    |> List.last() |> String.trim() 
    |> String.split(" ") |> List.first() 
    |> String.trim_trailing(".")
  end

  defp process_dns(domain) do
    if String.ends_with?(domain, [".xyz", ".top", ".cloud", ".zip"]) do
      dispatch(:track_suspicious, [domain])
    end
    dispatch(:track_domain, [domain])
  end

  # ==========================================
  # 🛰️ PRODUCTION DISPATCH LOGIC
  # ==========================================
  defp dispatch(func, args) do
    hub = Enum.find(Node.list(), fn n -> String.contains?(to_string(n), "hub") end)
    
    if hub do
      # Cast telemetry to Hub State over the network
      :rpc.cast(hub, Hacktui.State, func, args)
    else
      # Standalone/Hub local mode: Apply to local state if it exists
      if Process.whereis(Hacktui.State), do: apply(Hacktui.State, func, args)
    end
  end
end
