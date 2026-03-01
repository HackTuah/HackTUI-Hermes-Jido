defmodule Hacktui.Workers.NetScout do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    executable = System.find_executable("tcpdump")
    # Capturing raw UDP port 53 traffic for DNS anomalies
    port = Port.open({:spawn_executable, executable}, [
      :binary, :stream, :line, :stderr_to_stdout,
      args: ["-l", "-n", "-i", "any", "udp", "port", "53"]
    ])
    {:ok, %{port: port}}
  end

  def handle_info({_port, {:data, {:eol, line}}}, state) do
    if String.contains?(line, [" A? ", " AAAA? "]) do
      domain = line |> String.split([" A? ", " AAAA? "]) |> List.last() |> String.trim() |> String.split(" ") |> List.first() |> String.trim_trailing(".")
      process_dns(domain)
    else
      if String.match?(line, ~r/(error|denied|permitted)/i), do: Hacktui.State.add_log("NetScout: #{line}")
    end
    {:noreply, state}
  end

  defp process_dns(domain) do
    if String.ends_with?(domain, [".xyz", ".top", ".tk", ".cloud", ".zip"]), 
      do: Hacktui.State.add_alert("SUSPICIOUS DNS", "Attempted lookup: #{domain}")
    Hacktui.State.track_domain(domain)
  end

  def handle_info(_, state), do: {:noreply, state}
end
