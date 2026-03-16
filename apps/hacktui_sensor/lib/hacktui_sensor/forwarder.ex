defmodule HacktuiSensor.Forwarder do
  @moduledoc """
  Cluster-aware forwarding path for live sensor observations.

  Sensors run local collectors and forward normalized observations to the
  authoritative hub ingress service over Erlang distribution.
  """

  use GenServer

  alias HacktuiCore.Commands.AcceptObservation

  @name __MODULE__
  @default_retry_ms 5_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  def accept_observation(%AcceptObservation{} = attrs, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 15_000)
    GenServer.call(call_target(), {:accept_observation, normalize_attrs(attrs)}, timeout)
  end

  defp normalize_attrs(%_{} = attrs) do
    attrs
    |> Map.from_struct()
    |> normalize_attrs()
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    metadata =
      attrs
      |> Map.get(:metadata, %{})
      |> normalize_metadata()

    attrs
    |> Map.put(:metadata, metadata)
  end

  defp normalize_attrs(attrs), do: attrs

  defp normalize_metadata(nil), do: %{}

  defp normalize_metadata(%_{} = metadata) do
    metadata
    |> Map.from_struct()
    |> normalize_metadata()
  end

  defp normalize_metadata(metadata) when is_map(metadata) do
    Map.new(metadata, fn {key, value} ->
      {to_string(key), normalize_metadata_value(value)}
    end)
  end

  defp normalize_metadata(other), do: %{"value" => normalize_metadata_value(other)}

  defp normalize_metadata_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize_metadata_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)

  defp normalize_metadata_value(%_{} = value),
    do: value |> Map.from_struct() |> normalize_metadata()

  defp normalize_metadata_value(value) when is_map(value), do: normalize_metadata(value)

  defp normalize_metadata_value(value) when is_list(value),
    do: Enum.map(value, &normalize_metadata_value/1)

  defp normalize_metadata_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_metadata_value(value), do: value

  def child_spec(opts) do
    %{
      id: @name,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  @impl true
  def init(opts) do
    config = load_config(opts)

    state = %{
      connect_on_demand?: Keyword.get(config, :connect_on_demand?, true),
      connect_timeout: Keyword.get(config, :connect_timeout, 5_000),
      hub_module: Keyword.get(config, :hub_module, HacktuiHub.IngestService),
      hub_node: Keyword.get(config, :hub_node),
      retry_ms: Keyword.get(config, :retry_ms, @default_retry_ms)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:accept_observation, %AcceptObservation{} = command}, _from, state) do
    do_handle_accept_observation(command, state)
  end

  def handle_call({:accept_observation, command}, _from, state) when is_map(command) do
    command
    |> then(&struct(AcceptObservation, &1))
    |> do_handle_accept_observation(state)
  end

  defp do_handle_accept_observation(command, state) do
    case forward(command, state) do
      :ok ->
        {:reply, :ok, state}

      {:ok, events} when is_list(events) ->
        {:reply, {:ok, events}, increment_accepted(state, length(events))}

      {:ok, event} ->
        {:reply, {:ok, event}, increment_accepted(state, 1)}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp increment_accepted(state, count) do
    Map.update(state, :accepted, count, &(&1 + count))
  end

  defp forward(command, %{hub_module: hub_module, hub_node: nil}) do
    hub_module
    |> apply(:accept_observation, [command, []])
    |> normalize_rpc_result()
  end

  defp forward(command, %{hub_module: hub_module, hub_node: hub_node} = state) do
    with :ok <- ensure_connected(hub_node, state),
         result <-
           :rpc.call(hub_node, hub_module, :accept_observation, [command, []], rpc_timeout(state)) do
      normalize_rpc_result(result)
    end
  end

  defp ensure_connected(node_name, _state) when node() == node_name, do: :ok

  defp ensure_connected(node_name, %{connect_on_demand?: false}) do
    if node_name in Node.list(), do: :ok, else: {:error, {:hub_node_unreachable, node_name}}
  end

  defp ensure_connected(node_name, %{connect_timeout: timeout}) do
    if node_name in Node.list() do
      :ok
    else
      case Node.connect(node_name) do
        true -> wait_for_connection(node_name, timeout)
        false -> {:error, {:hub_node_unreachable, node_name}}
        :ignored -> {:error, {:distribution_not_started, node_name}}
      end
    end
  end

  defp call_target do
    case configured_hub_node() do
      nil -> @name
      hub_node when hub_node == node() -> @name
      hub_node -> {@name, hub_node}
    end
  end

  defp normalize_rpc_result(:ok), do: :ok
  defp normalize_rpc_result({:ok, _} = ok), do: ok
  defp normalize_rpc_result({:error, _} = error), do: error
  defp normalize_rpc_result({:badrpc, reason}), do: {:error, {:hub_rpc_failed, reason}}
  defp normalize_rpc_result(other), do: {:ok, other}

  defp wait_for_connection(node_name, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_connection(node_name, deadline)
  end

  defp do_wait_for_connection(node_name, deadline) do
    cond do
      node_name in Node.list() ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        {:error, {:hub_node_unreachable, node_name}}

      true ->
        Process.sleep(100)
        do_wait_for_connection(node_name, deadline)
    end
  end

  defp normalize_node(nil), do: nil
  defp normalize_node(""), do: nil
  defp normalize_node(node) when is_atom(node), do: node

  defp normalize_node(node) when is_binary(node) do
    node
    |> String.trim()
    |> case do
      "" -> nil
      value -> String.to_atom(value)
    end
  end

  defp load_config(opts) do
    app_config = Application.get_env(:hacktui_sensor, __MODULE__, [])

    app_config
    |> Keyword.put_new(:hub_node, Application.get_env(:hacktui_sensor, :hub_node))
    |> Keyword.merge(opts)
    |> Keyword.update(:hub_node, nil, &normalize_node/1)
  end

  defp configured_hub_node do
    Application.get_env(:hacktui_sensor, __MODULE__, [])
    |> Keyword.get_lazy(:hub_node, fn -> Application.get_env(:hacktui_sensor, :hub_node) end)
    |> normalize_node()
  end

  defp rpc_timeout(%{rpc_timeout: timeout, connect_timeout: connect_timeout})
       when is_integer(timeout) and timeout > 0 do
    max(timeout, connect_timeout)
  end

  defp rpc_timeout(state), do: max(state.connect_timeout, 15_000)
end
