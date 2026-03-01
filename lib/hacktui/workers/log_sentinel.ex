defmodule Hacktui.Workers.LogSentinel do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    # Stream the last 10 lines and then follow the journal live
    executable = System.find_executable("journalctl")
    port = Port.open({:spawn_executable, executable}, [
      :binary, :stream, :line,
      args: ["-n", "10", "-f", "-o", "short-iso"]
    ])
    {:ok, %{port: port}}
  end

  def handle_info({_port, {:data, {:eol, line}}}, state) do
    # Clean up the journal metadata for the TUI
    # Example: 2026-03-01T12:00:00 machine-name service[123]: message
    processed_line = line 
      |> String.split(" ") 
      |> Enum.drop(1) # Drop the timestamp for a cleaner look
      |> Enum.join(" ")

    Hacktui.State.add_log(processed_line)

    # Trigger alerts for specific critical events
    cond do
      String.contains?(line, "segfault") -> 
        Hacktui.State.add_alert("KERNEL", "Segment fault detected!")
      String.contains?(line, "denied") -> 
        Hacktui.State.add_alert("AUTH", "Permission denied event")
      true -> :ok
    end

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}
end
