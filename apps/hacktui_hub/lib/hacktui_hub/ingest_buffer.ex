defmodule HacktuiHub.IngestBuffer do
  @moduledoc """
  OTP GenServer providing a safe, bounded ring-buffer for live telemetry.
  This isolates telemetry state from the global BEAM heap to prevent 
  expensive garbage collection sweeps during high-throughput ingest.
  """
  use GenServer

  alias HacktuiCore.Events.ObservationAccepted

  @name __MODULE__
  @default_limit 100

  # --- Client API ---

  @doc """
  Starts the buffer GenServer.
  """
  def start_link(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    GenServer.start_link(__MODULE__, %{limit: limit, items: []}, name: @name)
  end

  @doc """
  Inserts a new observation into the ring buffer.
  Asynchronous cast to ensure the ingest pipeline isn't blocked by the UI.
  """
  @spec insert(ObservationAccepted.t()) :: :ok
  def insert(%ObservationAccepted{} = observation) do
    GenServer.cast(@name, {:insert, observation})
  end

  @doc """
  Retrieves the most recent observations from the buffer.
  """
  @spec get_recent() :: [ObservationAccepted.t()]
  def get_recent do
    GenServer.call(@name, :get_recent)
  end

  @doc """
  Clears all observations from the buffer.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.cast(@name, :clear)
  end

  # --- Server Callbacks ---

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:insert, obs}, %{limit: limit, items: items} = state) do
    # Deduplicate by observation_id and maintain strict buffer size
    updated_items =
      [obs | Enum.reject(items, &(&1.observation_id == obs.observation_id))]
      |> Enum.take(limit)

    {:noreply, %{state | items: updated_items}}
  end

  @impl true
  def handle_cast(:clear, state) do
    {:noreply, %{state | items: []}}
  end

  @impl true
  def handle_call(:get_recent, _from, %{items: items} = state) do
    {:reply, items, state}
  end
end
