defmodule HacktuiAgent.MCP.Schema do
  @moduledoc """
  Validates `tools/call` arguments against the JSON Schema the server advertises.

  The schemas at `MCP.Server.input_schema/1` were declared and never enforced — they were
  used only to build the `tools/list` response. `"additionalProperties" => false` and
  `"required"` were advertisement.

  That was exploitable. `normalize_arguments/1` retained unrecognised **string** keys;
  `ProposalService.propose_action/2` set its safety fields with **atom** keys via
  `Map.put_new`, which cannot see them; and `to_json_value/1` stringified and collapsed
  the collision with the caller's value winning. A client could send
  `{"requires_approval": false, "status": "approved"}` and receive a response asserting
  its own containment action was pre-approved.

  This is a deliberately small subset of JSON Schema — the keywords the server actually
  uses. It is not a general validator, and it refuses rather than guesses.
  """

  @type result :: :ok | {:error, String.t()}

  @doc """
  Validates `arguments` against `schema`.

  Returns `:ok`, or `{:error, reason}` naming the offending property.
  """
  @spec validate(map(), map()) :: result()
  def validate(arguments, schema) when is_map(arguments) and is_map(schema) do
    properties = Map.get(schema, "properties", %{})

    with :ok <- check_required(arguments, Map.get(schema, "required", [])),
         :ok <- check_additional(arguments, properties, schema) do
      check_properties(arguments, properties)
    end
  end

  def validate(_arguments, _schema), do: {:error, "arguments must be an object"}

  defp check_required(arguments, required) when is_list(required) do
    case Enum.reject(required, &Map.has_key?(arguments, &1)) do
      [] -> :ok
      missing -> {:error, "missing required propert#{plural(missing)}: #{join(missing)}"}
    end
  end

  defp check_required(_arguments, _), do: :ok

  defp check_additional(arguments, properties, schema) do
    if Map.get(schema, "additionalProperties", true) == false do
      case arguments |> Map.keys() |> Enum.reject(&Map.has_key?(properties, &1)) do
        [] -> :ok
        extra -> {:error, "unknown propert#{plural(extra)}: #{join(extra)}"}
      end
    else
      :ok
    end
  end

  defp check_properties(arguments, properties) do
    Enum.reduce_while(arguments, :ok, fn {key, value}, :ok ->
      case Map.fetch(properties, key) do
        {:ok, spec} ->
          case check_value(key, value, spec) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end

        :error ->
          {:cont, :ok}
      end
    end)
  end

  defp check_value(key, value, spec) do
    with :ok <- check_type(key, value, Map.get(spec, "type")),
         :ok <- check_enum(key, value, Map.get(spec, "enum")) do
      check_range(key, value, spec)
    end
  end

  defp check_type(_key, _value, nil), do: :ok
  defp check_type(_key, value, "string") when is_binary(value), do: :ok
  defp check_type(_key, value, "integer") when is_integer(value), do: :ok
  defp check_type(_key, value, "number") when is_number(value), do: :ok
  defp check_type(_key, value, "boolean") when is_boolean(value), do: :ok
  defp check_type(_key, value, "object") when is_map(value), do: :ok
  defp check_type(_key, value, "array") when is_list(value), do: :ok
  defp check_type(key, _value, type), do: {:error, "#{key} must be of type #{type}"}

  defp check_enum(_key, _value, nil), do: :ok

  defp check_enum(key, value, allowed) when is_list(allowed) do
    if value in allowed, do: :ok, else: {:error, "#{key} must be one of: #{join(allowed)}"}
  end

  defp check_range(key, value, spec) when is_number(value) do
    min = Map.get(spec, "minimum")
    max = Map.get(spec, "maximum")

    cond do
      is_number(min) and value < min -> {:error, "#{key} must be >= #{min}"}
      is_number(max) and value > max -> {:error, "#{key} must be <= #{max}"}
      true -> :ok
    end
  end

  defp check_range(_key, _value, _spec), do: :ok

  defp plural([_]), do: "y"
  defp plural(_), do: "ies"
  defp join(values), do: Enum.map_join(values, ", ", &to_string/1)
end
