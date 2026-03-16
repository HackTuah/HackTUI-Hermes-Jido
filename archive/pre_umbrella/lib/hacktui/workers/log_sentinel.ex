defmodule Hacktui.Workers.LogSentinel do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    executable = System.find_executable("journalctl")
    port = Port.open({:spawn_executable, executable}, [
      :binary, :stream, :line,
      args: ["-n", "10", "-f", "-o", "short-iso"]
    ])
    {:ok, %{port: port}}
  end

  def handle_info({_port, {:data, {:eol, line}}}, state) do
    processed_line = line 
      |> String.split(" ") 
      |> Enum.drop(1) 
      |> Enum.join(" ")

    # Use the HiveMind dispatch instead of direct local calls
    dispatch(:add_log, ["[#{node_prefix()}] #{processed_line}"])

    cond do
      String.contains?(line, "segfault") -> 
        dispatch(:add_alert, ["KERNEL", "Segment fault detected!"])
      String.contains?(line, "denied") -> 
        dispatch(:add_alert, ["AUTH", "Permission denied event"])
      true -> :ok
    end

    {:noreply, state}
  end

  defp node_prefix do
    current_node = node() |> to_string() |> String.split("@") |> hd()
    if current_node == "nonode@nohost", do: "LOCAL", else: String.upcase(current_node)
  end

  defp dispatch(function, args) do
    # Find the Hub on the network [cite: 56]
    hub_node = Enum.find(Node.list(), fn n -> String.contains?(to_string(n), "hub") end)

    if hub_node do
      # Remote procedure call to the Hub's state [cite: 56]
      :rpc.cast(hub_node, Hacktui.State, function, args)
    else
      # We are the Hub or Standalone; apply to local state [cite: 57]
      if Process.whereis(Hacktui.State), do: apply(Hacktui.State, function, args)
    end
  end
end
