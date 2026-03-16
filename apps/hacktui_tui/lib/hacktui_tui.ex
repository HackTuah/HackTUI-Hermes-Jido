defmodule ExRatatui.App do
  @moduledoc false

  @callback init(keyword()) :: {:ok, map()}
  @callback handle_key(term(), map()) :: {:ok, map()} | {:stop, map()}
  @callback handle_tick(map()) :: {:ok, map()} | {:stop, map()}
  @callback render(map(), keyword()) :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour ExRatatui.App

      def run(opts \\ []) do
        ExRatatui.App.run(__MODULE__, opts)
      end
    end
  end

  def run(module, opts \\ []) do
    {:ok, initial_state} = module.init(opts)
    refresh_ms = Map.get(initial_state, :refresh_ms, 1_000)

    terminal_state = enter_terminal()
    {:ok, tty} = File.open("/dev/tty", [:read, :binary])
    parent = self()
    reader = spawn(fn -> read_keys(parent, tty) end)

    try do
      loop(module, initial_state, refresh_ms)
    after
      Process.exit(reader, :kill)
      File.close(tty)
      leave_terminal(terminal_state)
    end
  end

  defp loop(module, state, refresh_ms) do
    {width, height} = terminal_size()
    IO.write(ansi_clear() <> ansi_home() <> module.render(state, width: width, height: height))

    receive do
      {:keypress, raw_key} ->
        case module.handle_key(normalize_key(raw_key), state) do
          {:ok, new_state} ->
            loop(module, new_state, refresh_ms)

          {:stop, final_state} ->
            {stop_width, stop_height} = terminal_size()

            IO.write(
              ansi_clear() <>
                ansi_home() <>
                module.render(final_state, width: stop_width, height: stop_height)
            )

            :ok
        end
    after
      refresh_ms ->
        case module.handle_tick(state) do
          {:ok, new_state} ->
            loop(module, new_state, refresh_ms)

          {:stop, final_state} ->
            {stop_width, stop_height} = terminal_size()

            IO.write(
              ansi_clear() <>
                ansi_home() <>
                module.render(final_state, width: stop_width, height: stop_height)
            )

            :ok
        end
    end
  end

  defp read_keys(parent, tty) do
    case IO.binread(tty, 1) do
      :eof ->
        :ok

      {:error, _reason} ->
        :ok

      data ->
        send(parent, {:keypress, data})
        read_keys(parent, tty)
    end
  end

  defp normalize_key(<<3>>), do: :interrupt
  defp normalize_key(<<9>>), do: :tab
  defp normalize_key(<<13>>), do: :enter
  defp normalize_key(<<10>>), do: :enter
  defp normalize_key(<<27>>), do: :escape
  defp normalize_key(<<127>>), do: :backspace
  defp normalize_key(<<8>>), do: :backspace
  defp normalize_key(key), do: key

  defp enter_terminal do
    tty_state = stty("-g")
    _ = stty("raw -echo")
    IO.write(ansi_alt_screen_on() <> ansi_hide_cursor() <> ansi_clear() <> ansi_home())
    tty_state
  end

  defp leave_terminal(nil) do
    IO.write(ansi_show_cursor() <> ansi_alt_screen_off())
  end

  defp leave_terminal(tty_state) do
    _ = stty(tty_state)
    IO.write(ansi_show_cursor() <> ansi_alt_screen_off())
  end

  defp terminal_size do
    from_erlang_io = fn ->
      with {:ok, cols} <- :io.columns(),
           {:ok, rows} <- :io.rows(),
           true <- is_integer(cols) and cols > 0 and is_integer(rows) and rows > 0 do
        {cols, rows}
      else
        _ -> nil
      end
    end

    from_python = fn ->
      code = "import os; s=os.get_terminal_size(); print(f'{s.columns} {s.lines}')"

      case System.cmd("python3", ["-c", code], stderr_to_stdout: true) do
        {output, 0} ->
          case String.split(String.trim(output), ~r/\s+/, parts: 2) do
            [cols, rows] ->
              with {cols_int, ""} <- Integer.parse(cols),
                   {rows_int, ""} <- Integer.parse(rows),
                   true <- cols_int > 0 and rows_int > 0 do
                {cols_int, rows_int}
              else
                _ -> nil
              end

            _ ->
              nil
          end

        _ ->
          nil
      end
    end

    from_tput = fn ->
      with {cols_out, 0} <- System.cmd("tput", ["cols"], stderr_to_stdout: true),
           {rows_out, 0} <- System.cmd("tput", ["lines"], stderr_to_stdout: true),
           {cols, ""} <- cols_out |> String.trim() |> Integer.parse(),
           {rows, ""} <- rows_out |> String.trim() |> Integer.parse(),
           true <- cols > 0 and rows > 0 do
        {cols, rows}
      else
        _ -> nil
      end
    end

    from_stty = fn ->
      case System.cmd("sh", ["-c", "stty size < /dev/tty"], stderr_to_stdout: true) do
        {output, 0} ->
          case String.split(String.trim(output), ~r/\s+/, parts: 2) do
            [rows, cols] ->
              with {rows_int, ""} <- Integer.parse(rows),
                   {cols_int, ""} <- Integer.parse(cols),
                   true <- rows_int > 0 and cols_int > 0 do
                {cols_int, rows_int}
              else
                _ -> nil
              end

            _ ->
              nil
          end

        _ ->
          nil
      end
    end

    from_erlang_io.() ||
      from_python.() ||
      from_tput.() ||
      from_stty.() ||
      {160, 48}
  end

  defp stty(args) do
    case System.cmd("sh", ["-c", "stty #{args} < /dev/tty"], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      _ -> nil
    end
  end

  defp ansi_alt_screen_on, do: "\e[?1049h"
  defp ansi_alt_screen_off, do: "\e[?1049l"
  defp ansi_hide_cursor, do: "\e[?25l"
  defp ansi_show_cursor, do: "\e[?25h"
  defp ansi_clear, do: "\e[2J"
  defp ansi_home, do: "\e[H"
end

defmodule HacktuiTui do
  @moduledoc false
  use ExRatatui.App

  @refresh_ms 1_000
  @max_history 40
  @panes [:alerts, :cases, :observations]

  @spec run_live_dashboard(keyword()) :: :ok
  def run_live_dashboard(opts \\ []) do
    run(opts)
  end

  def workflow_areas do
    [:alert_queue, :approval_inbox, :command_palette]
  end

  @impl true
  def init(opts) do
    refresh_ms = Keyword.get(opts, :refresh_ms, @refresh_ms)
    dashboard = live_snapshot("")

    {:ok,
     %{
       refresh_ms: refresh_ms,
       mode: :normal,
       query: "",
       pending_query: "",
       focused_pane: :alerts,
       dashboard: dashboard,
       selections: %{alerts: 0, cases: 0, observations: 0},
       history: [],
       status: snapshot_status(dashboard, "live dashboard ready"),
       tick_count: 0,
       exit_requested: false
     }}
  end

  defp live_snapshot(_query) do
    HacktuiHub.QueryService.live_dashboard_snapshot()
    |> normalize_snapshot()
  rescue
    _ ->
      %{
        alerts: [],
        cases: [],
        approvals: [],
        observations: [],
        telemetry: %{},
        health: %{summary: "status=unavailable"},
        refreshed_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
      }
  end

  @impl true
  def handle_key("q", state), do: {:stop, with_status(state, "quit requested", "quit requested")}

  def handle_key(:interrupt, state),
    do: {:stop, with_status(state, "interrupt requested", "interrupt requested")}

  def handle_key("/", %{mode: :search} = state) do
    {:ok,
     with_status(
       %{state | mode: :normal, pending_query: state.query},
       "search closed",
       "search closed"
     )}
  end

  def handle_key("/", state) do
    {:ok,
     with_status(
       %{state | mode: :search, pending_query: state.query},
       "search mode",
       "search opened"
     )}
  end

  def handle_key("h", %{mode: :help} = state) do
    {:ok, with_status(%{state | mode: :normal}, "help closed", "help closed")}
  end

  def handle_key("h", state) do
    {:ok, with_status(%{state | mode: :help}, "help opened", "help opened")}
  end

  def handle_key(:tab, %{mode: :normal} = state) do
    next_pane =
      case state.focused_pane do
        :alerts -> :cases
        :cases -> :observations
        :observations -> :alerts
      end

    {:ok,
     with_status(%{state | focused_pane: next_pane}, "focus=#{next_pane}", "focus #{next_pane}")}
  end

  def handle_key("j", %{mode: :normal} = state), do: {:ok, move_selection(state, 1)}
  def handle_key("k", %{mode: :normal} = state), do: {:ok, move_selection(state, -1)}

  def handle_key(:enter, %{mode: :search} = state) do
    query = String.trim(state.pending_query)

    {:ok,
     with_status(
       %{state | mode: :normal, query: query},
       search_status(query),
       "search #{inspect(query)}"
     )}
  end

  def handle_key(:backspace, %{mode: :search} = state) do
    trimmed =
      state.pending_query
      |> String.to_charlist()
      |> Enum.drop(-1)
      |> to_string()

    {:ok, %{state | pending_query: trimmed, status: "search=#{trimmed}"}}
  end

  def handle_key(:escape, %{mode: mode} = state) when mode in [:search, :help] do
    {:ok,
     with_status(
       %{state | mode: :normal, pending_query: state.query},
       "#{mode} closed",
       "#{mode} closed"
     )}
  end

  def handle_key(key, %{mode: :search} = state) when is_binary(key) and byte_size(key) == 1 do
    if printable?(key) do
      pending = state.pending_query <> key
      {:ok, %{state | pending_query: pending, status: "search=#{pending}"}}
    else
      {:ok, state}
    end
  end

  def handle_key(_key, state), do: {:ok, state}

  @impl true
  def handle_tick(state) do
    dashboard = live_snapshot(state.query)

    {:ok,
     %{
       state
       | dashboard: dashboard,
         tick_count: state.tick_count + 1,
         status: snapshot_status(dashboard, "live refresh #{state.tick_count + 1}")
     }}
  end

  @impl true
  def render(state, opts) do
    width = Keyword.get(opts, :width, 160)
    height = Keyword.get(opts, :height, 48)

    dashboard =
      current_dashboard(state)
      |> Map.put(:health, safe_health())
      |> Map.put(:refreshed_at, timestamp())
      |> Map.put(:history, state.history)
      |> Map.put(:status_line, state.status)

    ui = ui_state(state)

    HacktuiTui.LiveDashboardView.render(dashboard, ui, width: width, height: height)
  end

  defp current_dashboard(state) do
    state.dashboard
    |> normalize_snapshot()
    |> apply_search_filter(state.query)
  end

  defp normalize_snapshot(snapshot) when is_map(snapshot) do
    snapshot
    |> Map.put_new(:alerts, [])
    |> Map.put_new(:cases, [])
    |> Map.put_new(:approvals, [])
    |> Map.put_new(:observations, [])
    |> Map.put_new(:telemetry, %{})
  end

  defp normalize_snapshot(_snapshot) do
    %{
      alerts: [],
      cases: [],
      approvals: [],
      observations: [],
      telemetry: %{}
    }
  end

  defp snapshot_status(snapshot, prefix) do
    alerts = length(Map.get(snapshot, :alerts, []))
    cases = length(Map.get(snapshot, :cases, []))
    observations = length(Map.get(snapshot, :observations, []))
    "#{prefix} alerts=#{alerts} cases=#{cases} observations=#{observations}"
  end

  defp move_selection(state, delta) do
    pane = state.focused_pane
    count = pane_count(current_dashboard(state), pane)
    current = Map.get(state.selections, pane, 0)
    next_index = clamp(current + delta, 0, max(count - 1, 0))
    selections = Map.put(state.selections, pane, next_index)
    direction = if delta > 0, do: "down", else: "up"

    with_status(
      %{state | selections: selections},
      "selection #{direction}",
      "#{pane} row #{next_index + 1}"
    )
  end

  defp pane_count(data, :alerts), do: max(length(Map.get(data, :alerts, [])), 1)

  defp pane_count(data, :cases) do
    max(length(Map.get(data, :cases, [])) + length(Map.get(data, :approvals, [])), 1)
  end

  defp pane_count(data, :observations), do: max(length(Map.get(data, :observations, [])), 1)

  defp ui_state(state) do
    %{
      mode: state.mode,
      query: state.query,
      pending_query: state.pending_query,
      focused_pane: state.focused_pane,
      selected_pane: state.focused_pane,
      selected_index: Map.get(state.selections, state.focused_pane, 0),
      selections: state.selections,
      panes: @panes
    }
  end

  defp apply_search_filter(data, ""), do: data

  defp apply_search_filter(data, query) do
    matcher = matcher(query)

    %{
      data
      | alerts: Enum.filter(Map.get(data, :alerts, []), matcher),
        cases: Enum.filter(Map.get(data, :cases, []), matcher),
        approvals: Enum.filter(Map.get(data, :approvals, []), matcher),
        observations: Enum.filter(Map.get(data, :observations, []), matcher)
    }
  end

  defp matcher(query) do
    needle = String.downcase(query)

    fn value ->
      value
      |> inspect(pretty: false)
      |> String.downcase()
      |> String.contains?(needle)
    end
  end

  defp with_status(state, status, history_entry) do
    %{
      state
      | status: status,
        history: [timestamp() <> " " <> history_entry | state.history] |> Enum.take(@max_history)
    }
  end

  defp search_status(""), do: "search cleared"
  defp search_status(query), do: "search applied: #{query}"

  defp clamp(value, low, _high) when value < low, do: low
  defp clamp(value, _low, high) when value > high, do: high
  defp clamp(value, _low, _high), do: value

  defp printable?(<<char::utf8>>) when char >= 32 and char != 127, do: true
  defp printable?(_), do: false

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp safe_health do
    if Code.ensure_loaded?(HacktuiHub.Health) and function_exported?(HacktuiHub.Health, :status, 0) do
      try do
        HacktuiHub.Health.status()
      rescue
        _ -> %{summary: "status=unavailable"}
      catch
        :exit, _ -> %{summary: "status=unavailable"}
      end
    else
      %{summary: "status=unavailable"}
    end
  end
end
