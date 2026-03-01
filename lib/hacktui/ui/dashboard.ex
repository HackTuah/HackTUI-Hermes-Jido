defmodule Hacktui.UI.Dashboard do
  use ExRatatui.App
  import Ecto.Query

  alias ExRatatui.Widgets.{Paragraph, Block}
  alias ExRatatui.Layout
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style

  @impl true
  def mount(_opts) do
    :timer.send_interval(1000, :tick)
    {:ok, %{}}
  end

  @impl true
  def handle_event(event, state) do
    backend = Hacktui.State.get_state()
    event_str = inspect(event)

    # EMERGENCY OVERRIDE: Always allow quitting
    if event_str =~ "\"q\"" and not backend.input_mode do
      System.halt(0)
    end

    cond do
      # 1. Logic for when we are TYPING
      backend.input_mode ->
        cond do
          # Match "Enter" or "Esc" in any format (quoted or raw)
          String.contains?(String.downcase(event_str), ["enter", "return"]) ->
            execute_search(backend.search_query)
            Hacktui.State.clear_search_query()
            {:noreply, state}

          String.contains?(String.downcase(event_str), ["esc", "escape"]) ->
            Hacktui.State.clear_search_query()
            {:noreply, state}

          true ->
            # Better Key Extraction: Look for the 'ch' pattern specifically
            # Ratatui usually sends: {:key, %{code: {:ch, "a"}, ...}}
            case event do
              {:key, %{code: {:ch, char}}} -> 
                Hacktui.State.update_search_query(char)
              _ -> 
                :ok
            end
            {:noreply, state}
        end

      # 2. Regular Hotkeys (Only active when NOT typing)
      event_str =~ "\"s\"" ->
        Hacktui.State.toggle_input_mode()
        {:noreply, state}

      event_str =~ "\"c\"" ->
        Hacktui.State.clear_alerts()
        {:noreply, state}

      event_str =~ "\"h\"" ->
        fetch_history()
        {:noreply, state}

      true ->
        {:noreply, state}
    end
  end

  # Helper functions to keep handle_event clean
  defp execute_search(query_str) do
    query = from a in Hacktui.Schema.Alert, 
              where: ilike(a.message, ^"%#{query_str}%"), 
              order_by: [desc: a.inserted_at], 
              limit: 20
    results = Hacktui.Repo.all(query)
    Hacktui.State.add_log("[SEARCH] Found #{length(results)} matches for '#{query_str}'")
    Enum.each(results, fn a -> 
      Hacktui.State.add_log("[RESULT] #{a.type}: #{a.message}") 
    end)
  rescue
    e -> Hacktui.State.add_log("[!] Search failed: #{inspect(e)}")
  end

  defp fetch_history do
    query = from(a in Hacktui.Schema.Alert, order_by: [desc: a.inserted_at], limit: 20)
    history = Hacktui.Repo.all(query)
    Enum.each(history, fn a -> 
      Hacktui.State.add_log("[DB] #{a.type}: #{a.message}")
    end)
  rescue
    e -> Hacktui.State.add_log("[!] DB Query failed: #{inspect(e)}")
  end

  @impl true
  def handle_info(:tick, state), do: {:noreply, state}

  @impl true
  def render(_state, frame) do
    backend = Hacktui.State.get_state()
    area = %Rect{x: 0, y: 0, width: frame.width, height: frame.height}

    [top_r, main_r, bot_r] = Layout.split(area, :vertical, [
      {:length, 3}, {:percentage, 60}, {:min, 0}
    ])

    [left_r, right_r] = Layout.split(main_r, :horizontal, [
      {:percentage, 50}, {:percentage, 50}
    ])

    status_text = " 🛡️ HACKTUI | Alerts: #{length(backend.alerts)} | Logs: #{length(backend.logs)} | [q] Quit | [c] Clear | [h] History | [s] Search"
    top_bar = %Paragraph{
      text: status_text,
      style: %Style{fg: :cyan},
      block: %Block{borders: [:all], title: " System Status ", border_style: %Style{fg: :blue}}
    }

    alerts_content = if backend.alerts == [], do: "Watching for DNS anomalies...", else: 
      backend.alerts |> Enum.map(&"[!] #{&1.message}") |> Enum.join("\n")

    left_panel = %Paragraph{
      text: alerts_content,
      style: %Style{fg: :red},
      block: %Block{borders: [:all], title: " 🔥 ALERTS ", border_style: %Style{fg: :red}}
    }

    logs_content = if backend.logs == [], do: "Waiting for system events...", else: 
      backend.logs |> Enum.reverse() |> Enum.join("\n")
    
    right_panel = %Paragraph{
      text: logs_content,
      style: %Style{fg: :cyan},
      block: %Block{borders: [:all], title: " 📋 SYSTEM LOGS ", border_style: %Style{fg: :blue}}
    }

    # 3. Dynamic Bottom Panel: Toggles between Map and Search
    bottom_panel = if backend.input_mode do
      %Paragraph{
        text: " QUERY: #{backend.search_query}_",
        style: %Style{fg: :black, bg: :yellow},
        block: %Block{borders: [:all], title: " 🔍 SEARCH DATABASE (Press Enter to submit, Esc to cancel) ", border_style: %Style{fg: :yellow}}
      }
    else
      domains = backend.domains |> MapSet.to_list() |> Enum.join("  •  ")
      %Paragraph{
        text: if(domains == "", do: "No traffic detected yet...", else: domains),
        style: %Style{fg: :green},
        block: %Block{borders: [:all], title: " 🌐 NETWORK MAP ", border_style: %Style{fg: :green}}
      }
    end

    [{top_bar, top_r}, {left_panel, left_r}, {right_panel, right_r}, {bottom_panel, bot_r}]
  end
end
