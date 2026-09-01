defmodule HacktuiHub.ThreatIntel.Indexer do
  @moduledoc """
  In-memory index of threat-intel keywords, backed by an ETS table owned by this process.

  Each entry is `{normalised_keyword, %{keyword: , severity: , source: }}`. The map is
  what reaches an observation's `metadata[:threat_context]`, and it is the shape
  `HacktuiHub.Runtime.normalize_threat_context/1` and the TUI's threat marker both expect.

  The table is `:protected`: any process may read, only this one may write. It was
  `:public`, which let any process in the VM — including, over distribution, any
  cookie-authenticated node — insert false detections or delete real ones.
  """
  use GenServer

  require Logger

  @table_name :threat_intel_keywords

  @default_keywords [
    %{keyword: "mimikatz", severity: :high, source: "builtin"},
    %{keyword: "cobaltstrike", severity: :high, source: "builtin"},
    %{keyword: ~s(apparmor="denied"), severity: :medium, source: "builtin"},
    %{keyword: "nmap", severity: :medium, source: "builtin"}
  ]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "The ETS table name backing the index."
  @spec table() :: atom()
  def table, do: @table_name

  @doc """
  Replaces the index contents with `keywords`.

  Writes go through the owning process because the table is `:protected`.
  """
  @spec load(keyword()) :: :ok | {:error, term()}
  def load(opts) do
    keywords = opts |> Keyword.get(:keywords, []) |> Enum.map(&normalize_entry/1)

    GenServer.call(__MODULE__, {:load, keywords})
  end

  @doc """
  Returns the first entry whose keyword appears in `text`, or `nil`.

  The returned map is placed verbatim into `metadata[:threat_context]`.
  """
  @spec lookup(term()) :: map() | nil
  def lookup(text) when is_binary(text) do
    lowered = String.downcase(text)

    case :ets.whereis(@table_name) do
      :undefined ->
        nil

      _ref ->
        # try/after so an exception inside the fold cannot leave the table fixed.
        :ets.safe_fixtable(@table_name, true)

        try do
          :ets.foldl(
            fn
              {keyword, entry}, nil -> if String.contains?(lowered, keyword), do: entry, else: nil
              _entry, found -> found
            end,
            nil,
            @table_name
          )
        after
          :ets.safe_fixtable(@table_name, false)
        end
    end
  end

  def lookup(_text), do: nil

  @impl true
  def init(opts) do
    :ets.new(@table_name, [:set, :protected, :named_table, read_concurrency: true])

    keywords =
      opts
      |> Keyword.get(:keywords, @default_keywords)
      |> Enum.map(&normalize_entry/1)

    insert_all(keywords)
    {:ok, %{count: length(keywords)}}
  end

  @impl true
  def handle_call({:load, keywords}, _from, state) do
    :ets.delete_all_objects(@table_name)
    insert_all(keywords)
    {:reply, :ok, %{state | count: length(keywords)}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("[hacktui_hub] unmatched message in #{inspect(__MODULE__)}: #{inspect(msg)}")
    {:noreply, state}
  end

  defp insert_all(keywords) do
    Enum.each(keywords, fn %{keyword: keyword} = entry ->
      :ets.insert(@table_name, {String.downcase(keyword), entry})
    end)
  end

  defp normalize_entry(%{keyword: keyword} = entry) when is_binary(keyword) do
    %{
      keyword: keyword,
      severity: Map.get(entry, :severity, :medium),
      source: Map.get(entry, :source, "unknown")
    }
  end

  defp normalize_entry({keyword, description}) when is_binary(keyword) do
    %{keyword: keyword, severity: :medium, source: to_string(description)}
  end
end
