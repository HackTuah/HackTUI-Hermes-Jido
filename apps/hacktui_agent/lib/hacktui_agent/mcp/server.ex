defmodule HacktuiAgent.MCP.Server do
  @moduledoc false

  alias HacktuiAgent.MCP.Dispatch
  alias HacktuiAgent.MCP.ToolCatalog
  alias HacktuiAgent.MCP.ToolSpec

  @protocol_version "2024-11-05"
  @server_name "hacktui-hermes"
  @server_version "0.1.0"

  @type state :: %{
          dispatch: (atom(), map(), keyword() -> {:ok, term()} | {:error, term()}),
          dispatch_opts: keyword(),
          initialized?: boolean(),
          shutdown?: boolean(),
          tool_catalog: module()
        }

  @spec new(keyword()) :: state()
  def new(opts \\ []) do
    %{
      dispatch: Keyword.get(opts, :dispatch, &Dispatch.call/3),
      dispatch_opts: Keyword.get(opts, :dispatch_opts, []),
      initialized?: false,
      shutdown?: false,
      tool_catalog: Keyword.get(opts, :tool_catalog, ToolCatalog)
    }
  end

  @spec shutdown?(state()) :: boolean()
  def shutdown?(state), do: state.shutdown?

  @spec handle_message(state(), map()) :: {state(), map() | nil}
  def handle_message(state, %{"jsonrpc" => "2.0", "id" => id, "method" => "initialize"}) do
    response =
      result(id, %{
        "protocolVersion" => @protocol_version,
        "capabilities" => %{"tools" => %{"listChanged" => false}},
        "serverInfo" => %{"name" => @server_name, "version" => @server_version}
      })

    {%{state | initialized?: true}, response}
  end

  def handle_message(state, %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}) do
    {%{state | initialized?: true}, nil}
  end

  def handle_message(state, %{"jsonrpc" => "2.0", "id" => id, "method" => "ping"}) do
    {state, result(id, %{})}
  end

  def handle_message(state, %{"jsonrpc" => "2.0", "id" => id, "method" => "tools/list"}) do
    tools = Enum.map(state.tool_catalog.all(), &tool_definition/1)
    {state, result(id, %{"tools" => tools})}
  end

  def handle_message(
        state,
        %{
          "jsonrpc" => "2.0",
          "id" => id,
          "method" => "tools/call",
          "params" => %{"name" => name} = params
        }
      ) do
    arguments = Map.get(params, "arguments", %{})

    case normalize_tool_name(name) do
      {:ok, tool_name} ->
        response =
          case state.dispatch.(tool_name, normalize_arguments(arguments), state.dispatch_opts) do
            {:ok, payload} ->
              result(id, tool_success(payload))

            {:error, reason} ->
              result(id, tool_failure(reason))
          end

        {state, response}

      :error ->
        {state, error(id, -32_601, "Unknown tool: #{name}")}
    end
  end

  def handle_message(state, %{"jsonrpc" => "2.0", "id" => id, "method" => "shutdown"}) do
    {%{state | shutdown?: true}, result(id, %{})}
  end

  def handle_message(state, %{"jsonrpc" => "2.0", "method" => "exit"}) do
    {%{state | shutdown?: true}, nil}
  end

  def handle_message(state, %{"jsonrpc" => "2.0", "id" => id, "method" => method}) do
    {state, error(id, -32_601, "Method not found: #{method}")}
  end

  def handle_message(state, %{"id" => id}) do
    {state, error(id, -32_600, "Invalid Request")}
  end

  def handle_message(state, _message) do
    {state, nil}
  end

  defp tool_definition(%ToolSpec{} = tool) do
    %{
      "name" => Atom.to_string(tool.name),
      "description" => tool.description,
      "inputSchema" => input_schema(tool.name),
      "annotations" => %{
        "destructiveHint" => tool.mode == :proposal,
        "idempotentHint" => tool.mode == :read_only,
        "openWorldHint" => false,
        "readOnlyHint" => tool.mode == :read_only
      }
    }
  end

  defp tool_success(payload) do
    encoded = to_json_value(payload)

    %{
      "content" => [%{"type" => "text", "text" => Jason.encode!(encoded, pretty: true)}],
      "structuredContent" => encoded,
      "isError" => false
    }
  end

  defp tool_failure(reason) do
    message = format_reason(reason)

    %{
      "content" => [%{"type" => "text", "text" => message}],
      "structuredContent" => %{"error" => message},
      "isError" => true
    }
  end

  defp normalize_tool_name(name) when is_binary(name) do
    valid_names = Enum.map(ToolCatalog.all(), &Atom.to_string(&1.name))

    if name in valid_names do
      {:ok, String.to_existing_atom(name)}
    else
      :error
    end
  end

  defp normalize_tool_name(name) when is_atom(name), do: {:ok, name}
  defp normalize_tool_name(_name), do: :error

  defp normalize_arguments(arguments) when is_map(arguments) do
    Enum.reduce(arguments, %{}, fn {key, value}, acc ->
      normalized_value = normalize_argument_value(key, value)

      case normalize_argument_key(key) do
        {:ok, atom_key} ->
          acc
          |> Map.put(key, normalized_value)
          |> Map.put(atom_key, normalized_value)

        :error ->
          Map.put(acc, key, normalized_value)
      end
    end)
  end

  defp normalize_arguments(_), do: %{}

  defp normalize_argument_key(key) when is_atom(key), do: {:ok, key}

  defp normalize_argument_key(key) when is_binary(key) do
    case key do
      "action_class" -> {:ok, :action_class}
      "case_id" -> {:ok, :case_id}
      "format" -> {:ok, :format}
      "limit" -> {:ok, :limit}
      "rationale" -> {:ok, :rationale}
      "summary" -> {:ok, :summary}
      "target" -> {:ok, :target}
      _ -> :error
    end
  end

  defp normalize_argument_key(_key), do: :error

  defp normalize_argument_value("action_class", value) when is_binary(value) do
    case value do
      "contain" -> :contain
      "observe" -> :observe
      "notify_export" -> :notify_export
      other -> other
    end
  end

  defp normalize_argument_value(_key, value) when is_map(value), do: to_json_value(value)
  defp normalize_argument_value(_key, value) when is_list(value), do: Enum.map(value, &to_json_value/1)
  defp normalize_argument_value(_key, value), do: value

  defp input_schema(:get_latest_alerts) do
    %{
      "type" => "object",
      "properties" => %{
        "limit" => %{
          "type" => "integer",
          "description" => "Maximum number of alert queue entries to return.",
          "minimum" => 1,
          "maximum" => 100
        }
      },
      "additionalProperties" => false
    }
  end

  defp input_schema(:get_case_timeline) do
    %{
      "type" => "object",
      "properties" => %{
        "case_id" => %{
          "type" => "string",
          "description" => "Case identifier to inspect."
        }
      },
      "required" => ["case_id"],
      "additionalProperties" => false
    }
  end

  defp input_schema(:draft_report) do
    %{
      "type" => "object",
      "properties" => %{
        "case_id" => %{
          "type" => "string",
          "description" => "Case identifier to draft a report for."
        },
        "format" => %{
          "type" => "string",
          "description" => "Optional report format hint."
        }
      },
      "required" => ["case_id"],
      "additionalProperties" => false
    }
  end

  defp input_schema(:propose_action) do
    %{
      "type" => "object",
      "properties" => %{
        "case_id" => %{
          "type" => "string",
          "description" => "Case identifier for the action request."
        },
        "action_class" => %{
          "type" => "string",
          "description" => "Action class to propose.",
          "enum" => ["contain", "observe", "notify_export"]
        },
        "target" => %{
          "type" => "string",
          "description" => "Target host, identity, or resource."
        },
        "rationale" => %{
          "type" => "string",
          "description" => "Why the action is being proposed."
        }
      },
      "required" => ["case_id", "action_class", "target"],
      "additionalProperties" => false
    }
  end

  defp input_schema(_tool_name) do
    %{"type" => "object", "properties" => %{}, "additionalProperties" => true}
  end

  defp to_json_value(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      normalized_key = if is_atom(key), do: Atom.to_string(key), else: key
      {normalized_key, to_json_value(nested_value)}
    end)
  end

  defp to_json_value(value) when is_list(value), do: Enum.map(value, &to_json_value/1)
  defp to_json_value(value) when is_atom(value), do: Atom.to_string(value)
  defp to_json_value(value), do: value

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp result(id, payload), do: %{"jsonrpc" => "2.0", "id" => id, "result" => payload}

  defp error(id, code, message) do
    %{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}}
  end
end
