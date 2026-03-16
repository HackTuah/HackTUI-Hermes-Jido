defmodule Hacktui.MCP.Protocol do
  @moduledoc false

  @protocol_version "2024-11-05"

  def protocol_version, do: @protocol_version

  def handle_message(%{"method" => "initialize", "id" => id}) do
    response(id, %{
      "protocolVersion" => @protocol_version,
      "capabilities" => %{"tools" => %{"listChanged" => false}},
      "serverInfo" => %{
        "name" => "hacktui",
        "version" => to_string(Application.spec(:hacktui, :vsn) || "0.1.0")
      },
      "instructions" => "HackTUI exposes SecOps telemetry helpers over MCP tools. Use tools/list then tools/call."
    })
  end

  def handle_message(%{"method" => "notifications/initialized"}), do: nil

  def handle_message(%{"method" => "ping", "id" => id}) do
    response(id, %{})
  end

  def handle_message(%{"method" => "tools/list", "id" => id}) do
    response(id, %{"tools" => tools()})
  end

  def handle_message(%{"method" => "tools/call", "id" => id, "params" => %{"name" => name} = params}) do
    arguments = Map.get(params, "arguments", %{}) || %{}

    case call_tool(name, arguments) do
      {:ok, result} -> tool_result(id, result)
      {:error, message} -> tool_result(id, %{"error" => message}, true)
    end
  end

  def handle_message(%{"method" => "report_plan", "id" => id, "params" => params}) do
    params
    |> Map.get("text")
    |> report_plan_response()
    |> legacy_to_response(id)
  end

  def handle_message(%{"method" => "clear_plan", "id" => id}) do
    legacy_to_response({:ok, %{"status" => "plan_cleared"}}, id)
  end

  def handle_message(%{"method" => _method, "id" => id}) do
    error(id, -32601, "Method not implemented")
  end

  def handle_message(_message) do
    error(nil, -32600, "Invalid Request")
  end

  def tools do
    [
      %{
        "name" => "report_plan",
        "description" => "Display the agent's current investigation plan inside HackTUI.",
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{
            "text" => %{"type" => "string", "description" => "Plan text to display in the dashboard."}
          },
          "required" => ["text"],
          "additionalProperties" => false
        }
      },
      %{
        "name" => "clear_plan",
        "description" => "Clear the currently displayed investigation plan from HackTUI.",
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{},
          "additionalProperties" => false
        }
      },
      %{
        "name" => "get_latest_alerts",
        "description" => "Return the latest in-memory HackTUI alerts.",
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{
            "limit" => %{"type" => "integer", "minimum" => 1, "maximum" => 50, "default" => 5}
          },
          "additionalProperties" => false
        }
      },
      %{
        "name" => "get_sensor_logs",
        "description" => "Return the latest in-memory HackTUI sensor logs.",
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{
            "limit" => %{"type" => "integer", "minimum" => 1, "maximum" => 100, "default" => 20}
          },
          "additionalProperties" => false
        }
      }
    ]
  end

  defp call_tool("report_plan", %{"text" => text}) when is_binary(text) do
    report_plan_response(text)
  end

  defp call_tool("clear_plan", _arguments) do
    maybe_clear_plan()
    {:ok, %{"status" => "plan_cleared"}}
  end

  defp call_tool("get_latest_alerts", arguments) do
    limit = bounded_limit(arguments, "limit", 5, 50)
    alerts = current_state().alerts |> Enum.take(limit)
    {:ok, %{"alerts" => alerts, "count" => length(alerts)}}
  end

  defp call_tool("get_sensor_logs", arguments) do
    limit = bounded_limit(arguments, "limit", 20, 100)
    logs = current_state().logs |> Enum.take(limit)
    {:ok, %{"logs" => logs, "count" => length(logs)}}
  end

  defp call_tool(_name, _arguments), do: {:error, "Unknown tool"}

  defp report_plan_response(text) when is_binary(text) do
    maybe_set_plan(text)
    {:ok, %{"status" => "displaying_plan", "text" => text}}
  end

  defp report_plan_response(_invalid), do: {:error, "Missing required argument: text"}

  defp bounded_limit(arguments, key, default, max) do
    arguments
    |> Map.get(key, default)
    |> normalize_limit(default, max)
  end

  defp normalize_limit(limit, _default, max) when is_integer(limit), do: min(max(limit, 1), max)
  defp normalize_limit(_limit, default, _max), do: default

  defp current_state do
    if Process.whereis(Hacktui.State) do
      Hacktui.State.get_state()
    else
      %{alerts: [], logs: []}
    end
  end

  defp maybe_set_plan(text) do
    if Process.whereis(Hacktui.State), do: Hacktui.State.set_planning_text(text)
  end

  defp maybe_clear_plan do
    if Process.whereis(Hacktui.State), do: Hacktui.State.clear_planning_text()
  end

  defp legacy_to_response({:ok, result}, id), do: response(id, result)
  defp legacy_to_response({:error, message}, id), do: error(id, -32602, message)

  defp response(id, result) do
    %{"jsonrpc" => "2.0", "id" => id, "result" => result}
  end

  defp error(id, code, message) do
    %{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}}
  end

  defp tool_result(id, structured_content, is_error \\ false) do
    text = Jason.encode!(structured_content)

    response(id, %{
      "content" => [%{"type" => "text", "text" => text}],
      "structuredContent" => structured_content,
      "isError" => is_error
    })
  end
end
