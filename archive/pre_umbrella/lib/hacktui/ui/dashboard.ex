defmodule Hacktui.UI.Dashboard do
  use ExRatatui.App
  import Ecto.Query

  alias ExRatatui.Widgets.{Paragraph, Block}
  alias ExRatatui.Layout
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style

  @impl true
  def mount(_opts) do
    # Increased tick rate slightly for smoother updates, 
    # but the state itself is now the source of truth for EPS.
    :timer.send_interval(500, :tick)
    {:ok, %{}}
  end

  @impl true
  def handle_event(event, state) do
    backend = Hacktui.State.get_state()
    event_str = inspect(event)

    if event_str =~ "\"q\"" and not backend.input_mode, do: System.halt(0)

    cond do
      backend.input_mode ->
        handle_input(event, event_str, backend, state)
      event_str =~ "\"s\"" ->
        Hacktui.State.toggle_input_mode()
        {:noreply, state}
      event_str =~ "\"c\"" ->
        Hacktui.State.clear_alerts()
        {:noreply, state}
      event_str =~ "\"h\"" ->
        fetch_history()
        {:noreply, state}
      true -> {:noreply, state}
    end
  end

  defp handle_input(event, event_str, backend, state) do
    cond do
      String.contains?(String.downcase(event_str), ["enter", "return"]) ->
        execute_search(backend.search_query)
        Hacktui.State.clear_search_query()
        {:noreply, state}
      String.contains?(String.downcase(event_str), ["esc", "escape"]) ->
        Hacktui.State.clear_search_query()
        {:noreply, state}
      true ->
        case event do
          {:key, %{code: {:ch, char}}} -> Hacktui.State.update_search_query(char)
          {:key, %{code: :backspace}} -> # Basic backspace support
             # Implementation omitted for brevity, focusing on performance
             :ok
          _ -> :ok
        end
        {:noreply, state}
    end
  end

  defp execute_search(query_str) do
    # Background the search so we don't freeze the TUI during DB IO
    Task.start(fn -> 
      query = from a in Hacktui.Schema.Alert, 
              where: ilike(a.message, ^"%#{query_str}%"), 
              order_by: [desc: a.inserted_at], 
              limit: 10
      results = Hacktui.Repo.all(query)
      Hacktui.State.add_log("[SEARCH] Found #{length(results)} matches for '#{query_str}'")
      Enum.each(results, fn a -> Hacktui.State.add_log("[RESULT] #{a.type}: #{a.message}") end)
    end)
  rescue
    e -> Hacktui.State.add_log("[!] Search failed: #{inspect(e)}")
  end

  defp fetch_history do
    Task.start(fn -> 
      query = from(a in Hacktui.Schema.Alert, order_by: [desc: a.inserted_at], limit: 15)
      history = Hacktui.Repo.all(query)
      Enum.each(history, fn a -> Hacktui.State.add_log("[DB] #{a.type}: #{a.message}") end)
    end)
  rescue
    e -> Hacktui.State.add_log("[!] History failed: #{inspect(e)}")
  end

  @impl true
  def handle_info(:tick, state), do: {:noreply, state}

  @impl true
  def render(_state, frame) do
    backend = Hacktui.State.get_state()
    area = %Rect{x: 0, y: 0, width: frame.width, height: frame.height}
    
    eps = get_in(backend, [:metrics, :eps]) || 0
    connected_nodes = length(Node.list())
    cluster_status = if connected_nodes > 0, do: " | 🛰️ Cluster: #{connected_nodes} Sensors", else: " | 📡 Cluster: Offline"

    [top_r, main_r, bot_r] = Layout.split(area, :vertical, [{:length, 3}, {:percentage, 65}, {:min, 0}])
    [left_r, right_r] = Layout.split(main_r, :horizontal, [{:percentage, 40}, {:percentage, 60}])

    top_bar = %Paragraph{
      text: " 🛡️ HACKTUI | EPS: #{eps} | Alerts: #{length(backend.alerts)} | Nodes: #{connected_nodes}#{cluster_status} | [q] Quit | [s] Search",
      style: %Style{fg: :cyan},
      block: %Block{borders: [:all], title: " System Status ", border_style: %Style{fg: :blue}}
    }

    alerts_content = backend.alerts |> Enum.map(&"[!] #{&1.message}") |> Enum.join("\n")
    left_panel = %Paragraph{text: alerts_content, style: %Style{fg: :red}, block: %Block{borders: [:all], title: " 🔥 ALERTS ", border_style: %Style{fg: :red}}}

    # Optimized log display: don't reverse the whole list every frame
    logs_content = backend.logs |> Enum.join("\n")
    right_panel = %Paragraph{text: logs_content, style: %Style{fg: :cyan}, block: %Block{borders: [:all], title: " 📋 SYSTEM LOGS ", border_style: %Style{fg: :blue}}}

    bottom_panel = cond do
      backend.input_mode ->
        %Paragraph{text: " QUERY: #{backend.search_query}_", style: %Style{fg: :black, bg: :yellow}, block: %Block{borders: [:all], title: " 🔍 SEARCH DATABASE ", border_style: %Style{fg: :yellow}}}

      # ✅ Hermes Logic UI panel priority added here
      Map.get(backend, :planning_text) != nil ->
        %Paragraph{
          text: "🤖 AGENT LOGIC:\n#{backend.planning_text}", 
          style: %Style{fg: :magenta}, 
          block: %Block{borders: [:all], title: " 🧠 HERMES THINKING... ", border_style: %Style{fg: :magenta}}
        }

      true ->
        intel_lines = Enum.map(backend.intel_map, fn {domain, data} ->
          risk = get_risk_indicator(domain, data.isp)
          "#{risk} | #{String.pad_trailing(domain, 20)} | #{String.pad_trailing(data.ip, 15)} | #{data.country}"
        end)
        %Paragraph{text: Enum.join(intel_lines, "\n"), style: %Style{fg: :green}, block: %Block{borders: [:all], title: " 🌐 INTEL MAP ", border_style: %Style{fg: :green}}}
    end

    [{top_bar, top_r}, {left_panel, left_r}, {right_panel, right_r}, {bottom_panel, bot_r}]
  end

  defp get_risk_indicator(domain, isp) do
    safe_isp = isp || ""
    cond do
      safe_isp == "UNRESOLVED/NXDOMAIN" -> "🔴 [DEAD]"
      String.ends_with?(domain, [".zip", ".cloud"]) -> "🔴 [CRITICAL]"
      true -> "🟡 [QUERY]"
    end
  end
end
