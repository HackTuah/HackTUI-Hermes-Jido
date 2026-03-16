defmodule Hacktui.Application do
  use Application

  @impl true
  def start(_type, _args) do
    if Node.alive?() do
      target_cookie = System.get_env("HACKTUI_COOKIE") || "hacktui_secret"
      Node.set_cookie(String.to_atom(target_cookie))
    end

    mode = runtime_mode()
    show_tui? = show_tui?(mode)

    maybe_emit_boot_banner(mode, show_tui?)

    children =
      mode
      |> children_for(show_tui?)
      |> maybe_add_dashboard(show_tui?)

    opts = [strategy: :one_for_one, name: Hacktui.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def runtime_mode do
    case System.get_env("HACKTUI_MODE") do
      "HUB" -> :hub
      "MCP" -> :mcp
      _ -> :sensor
    end
  end

  def show_tui?(:hub), do: System.get_env("HACKTUI_TUI") != "OFF"
  def show_tui?(_mode), do: false

  def children_for(:hub, _show_tui?) do
    [
      Hacktui.Repo,
      Hacktui.Cluster,
      Hacktui.State,
      Hacktui.Workers.Enricher,
      Hacktui.Workers.HermesBridge
    ]
  end

  def children_for(:mcp, _show_tui?) do
    [Hacktui.State]
  end

  def children_for(:sensor, _show_tui?) do
    [
      Hacktui.Cluster,
      Hacktui.Workers.LogSentinel,
      Hacktui.Workers.NetScout
    ]
  end

  defp maybe_emit_boot_banner(:hub, show_tui?) do
    IO.puts("""
    ========================================
    🛡️  HACKTUI SYSTEM BOOT
    NODE:   #{node()}
    COOKIE: #{if Node.alive?(), do: Node.get_cookie(), else: "N/A (Non-Distributed)"}
    MODE:   CENTRAL HUB
    TUI:    #{if show_tui?, do: "ENABLED", else: "DISABLED"}
    ========================================
    """)
  end

  defp maybe_emit_boot_banner(_mode, _show_tui?), do: :ok

  defp maybe_add_dashboard(children, true), do: children ++ [Hacktui.UI.Dashboard]
  defp maybe_add_dashboard(children, false), do: children
end
