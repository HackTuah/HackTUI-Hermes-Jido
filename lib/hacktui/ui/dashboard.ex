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
    event_str = inspect(event)

    cond do
      # Looking for exact quoted letters so it doesn't match words like "ctrl" or "ch"
      event_str =~ "\"q\"" ->
        System.halt(0)
        {:stop, state}

      event_str =~ "\"c\"" ->
        Hacktui.State.clear_alerts()
        {:noreply, state}

      event_str =~ "\"h\"" ->
        try do
          query = from(a in Hacktui.Schema.Alert, order_by: [desc: a.inserted_at], limit: 20)
          history = Hacktui.Repo.all(query)
          
          if history == [] do
             Hacktui.State.add_log("[DB_HISTORY] No alerts found in database.")
          else
            Enum.each(history, fn a -> 
              msg = "[DB_HISTORY] #{a.inserted_at} | #{a.type}: #{a.message}"
              Hacktui.State.add_log(msg)
            end)
          end
        rescue
          e -> Hacktui.State.add_log("[!] Database query failed: #{inspect(e)}")
        end
        {:noreply, state}

      true ->
        {:noreply, state}
    end
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

    status_text = " 🛡️ HACKTUI | Alerts: #{length(backend.alerts)} | Logs: #{length(backend.logs)} | [q] Quit | [c] Clear | [h] History"
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

    domains = backend.domains |> MapSet.to_list() |> Enum.join("  •  ")
    network_map = %Paragraph{
      text: if(domains == "", do: "No traffic detected yet...", else: domains),
      style: %Style{fg: :green},
      block: %Block{borders: [:all], title: " 🌐 NETWORK MAP ", border_style: %Style{fg: :green}}
    }

    [{top_bar, top_r}, {left_panel, left_r}, {right_panel, right_r}, {network_map, bot_r}]
  end
end
