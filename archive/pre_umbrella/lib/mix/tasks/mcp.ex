defmodule Mix.Tasks.Mcp do
  @moduledoc """
  Hardened MCP (Model Context Protocol) server for HackTUI.
  Allows Hermes (GPT-5.4 / Codex) to report reasoning and plan execution
  while maintaining full protocol compliance.
  """
  use Mix.Task
  import Ecto.Query
  require Logger

  def run(_args) do
    # MANDATORY: Silence all logs that might leak into stdout.
    Logger.configure(level: :error)
    
    # Ensure the HackTUI application is running for state/repo access.
    Application.ensure_all_started(:hacktui)
    
    # Report status to stderr so it doesn't break the JSON-RPC pipe on stdout.
    IO.puts(:stderr, "[HACKTUI-MCP] Active. Ready for Agent Reasonings.")
    
    receive_loop()
  end

  defp receive_loop do
    case IO.read(:line) do
      :eof -> :ok
      line ->
        line 
        |> String.trim() 
        |> handle_request()
        receive_loop()
    end
  end

  # --- Request Handling ---

  defp handle_request(""), do: :ok
  defp handle_request(line) do
    case Jason.decode(line) do
      # Protocol Handshake
      {:ok, %{"method" => "initialize", "id" => id}} ->
        send_initialize_response(id)

      # Discovery
      {:ok, %{"method" => "tools/list", "id" => id}} ->
        send_tools_list(id)

      # Execution / Custom Methods
      {:ok, %{"method" => "tools/call", "params" => %{"name" => name, "arguments" => args}, "id" => id}} ->
        handle_tool_call(id, name, args)

      # LEGACY/CUSTOM: Support for direct method calls if needed by older configurations
      {:ok, %{"method" => "report_plan", "params" => %{"text" => plan}, "id" => id}} ->
        Hacktui.State.add_log("[PLAN] 🤖 #{plan}")
        # Note: If you added a specific 'planning_text' field to State, call it here.
        # For now, we inject it into the system logs for visibility.
        respond(id, %{status: "displaying_plan"})

      {:ok, %{"method" => "clear_plan", "id" => id}} ->
        respond(id, %{status: "plan_cleared"})

      {:ok, %{"method" => "notifications/initialized"}} ->
        :ok

      {:error, _} -> 
        send_error(nil, "Invalid JSON")

      _ -> :ok
    end
  rescue
    e -> 
      IO.puts(:stderr, "[MCP ERROR] #{inspect(e)}")
      :ok
  end

  # --- MCP Protocol Responses ---

  defp send_initialize_response(id) do
    respond(id, %{
      "protocolVersion" => "2024-11-05",
      "capabilities" => %{
        "tools" => %{"listChanged" => false}
      },
      "serverInfo" => %{"name" => "hacktui-mcp", "version" => "1.1.0"}
    })
  end

  defp send_tools_list(id) do
    respond(id, %{
      "tools" => [
        %{
          "name" => "get_latest_alerts",
          "description" => "Retrieves historical security alerts from the database.",
          "inputSchema" => %{
            "type" => "object",
            "properties" => %{
              "limit" => %{"type" => "integer", "description" => "Number of alerts to fetch"}
            }
          }
        },
        %{
          "name" => "get_sensor_logs",
          "description" => "Fetches recent system logs from the HackTUI state.",
          "inputSchema" => %{"type" => "object", "properties" => %{}}
        },
        %{
          "name" => "report_plan",
          "description" => "Updates the TUI status with the agent's current reasoning or plan.",
          "inputSchema" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{"type" => "string"}
            },
            "required" => ["text"]
          }
        }
      ]
    })
  end

  # --- Tool Logic ---

  defp handle_tool_call(id, "get_latest_alerts", args) do
    limit = Map.get(args, "limit", 5)
    query = from(a in Hacktui.Schema.Alert, order_by: [desc: a.inserted_at], limit: ^limit)
    alerts = Hacktui.Repo.all(query)
    
    text = Enum.map_join(alerts, "\n", fn a -> "[#{a.inserted_at}] #{a.type}: #{a.message}" end)
    respond(id, %{"content" => [%{"type" => "text", "text" => text}]})
  end

  defp handle_tool_call(id, "get_sensor_logs", _args) do
    state = Hacktui.State.get_state()
    text = Enum.join(state.logs, "\n")
    respond(id, %{"content" => [%{"type" => "text", "text" => text}]})
  end

  defp handle_tool_call(id, "report_plan", %{"text" => plan}) do
    Hacktui.State.add_log("[AGENT PLAN] 🧠 #{plan}")
    respond(id, %{"content" => [%{"type" => "text", "text" => "Plan reported to TUI"}]})
  end

  defp handle_tool_call(id, _, _) do
    send_error(id, "Method not found")
  end

  # --- Helpers ---

  defp respond(id, result) do
    IO.puts(Jason.encode!(%{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => result
    }))
  end

  defp send_error(id, msg) do
    IO.puts(Jason.encode!(%{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => %{"code" => -32603, "message" => msg}
    }))
  end
end
