defmodule Hacktui.UI.Dashboard do
  use ExRatatui.App

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
    cond do
      inspect(event) =~ "q" ->
        System.halt(0)
        {:stop, state}
      inspect(event) =~ "c" ->
        # Calls the clear_alerts function in your State GenServer
        Hacktui.State.clear_alerts()
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
    # Convert Frame to Rect for stable 0.4.1 layout splitting
    area = %Rect{x: 0, y: 0, width: frame.width, height: frame.height}

    # Split: Top Bar (3), Main (60%), Bottom (Remaining)
    [top_r, main_r, bot_r] = Layout.split(area, :vertical, [
      {:length, 3}, {:percentage, 60}, {:min, 0}
    ])

    [left_r, right_r] = Layout.split(main_r, :horizontal, [
      {:percentage, 50}, {:percentage, 50}
    ])

    # 1. Top Bar (With Unique Domains counter)
    status_text = " 🛡️ HACKTUI | Alerts: #{length(backend.alerts)} | Logs: #{length(backend.logs)} | Unique Domains: #{MapSet.size(backend.domains)} | [q] Quit | [c] Clear"
    top_bar = %Paragraph{
      text: status_text,
      style: %Style{fg: :cyan},
      block: %Block{borders: [:all], title: " System Status ", border_style: %Style{fg: :blue}}
    }

    # 2. Alerts (Red)
    alerts_content = if backend.alerts == [], do: "Watching for DNS anomalies...", else: 
      backend.alerts |> Enum.map(&"[!] #{&1.message}") |> Enum.join("\n")

    left_panel = %Paragraph{
      text: alerts_content,
      style: %Style{fg: :red},
      block: %Block{borders: [:all], title: " 🔥 ALERTS ", border_style: %Style{fg: :red}}
    }

    # 3. Logs (Cyan)
    logs_content = if backend.logs == [], do: "Waiting for system events...", else: 
      backend.logs |> Enum.reverse() |> Enum.join("\n")
    
    right_panel = %Paragraph{
      text: logs_content,
      style: %Style{fg: :cyan},
      block: %Block{borders: [:all], title: " 📋 SYSTEM LOGS ", border_style: %Style{fg: :blue}}
    }

    # 4. Network Map (Green)
    domains = backend.domains |> MapSet.to_list() |> Enum.join("  •  ")
    network_map = %Paragraph{
      text: if(domains == "", do: "No traffic detected yet...", else: domains),
      style: %Style{fg: :green},
      block: %Block{borders: [:all], title: " 🌐 NETWORK MAP ", border_style: %Style{fg: :green}}
    }

    [{top_bar, top_r}, {left_panel, left_r}, {right_panel, right_r}, {network_map, bot_r}]
  end
end
