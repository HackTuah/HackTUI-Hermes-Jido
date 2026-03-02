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
      domain = line 
      |> String.split([" A? ", " AAAA? "]) 
      |> List.last() 
      |> String.trim() 
      |> String.split(" ") 
      |> List.first() 
      |> String.trim_trailing(".")
      
      process_dns(domain)
    else
      if String.match?(line, ~r/(error|denied|permitted)/i) do
        Hacktui.State.add_log("NetScout: #{line}")
      end
    end
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp process_dns(domain) do
    if String.ends_with?(domain, [".xyz", ".top", ".tk", ".cloud", ".zip"]) do
      
      Hacktui.State.track_suspicious(domain)
    end
    Hacktui.State.track_domain(domain)
  end
end
