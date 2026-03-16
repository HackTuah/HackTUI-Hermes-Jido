defmodule HacktuiTui.LiveDashboardView do
  @moduledoc false

  alias HacktuiHub.PrivacyMask

  @reset "\e[0m"
  @bold "\e[1m"

  @fg_purple "\e[38;5;141m"
  @fg_red "\e[38;5;196m"
  @fg_yellow "\e[38;5;220m"
  @fg_green "\e[38;5;48m"
  @fg_cyan "\e[38;5;45m"
  @fg_base "\e[38;5;250m"
  @fg_white "\e[38;5;255m"
  @fg_dim "\e[38;5;242m"

  @bg_selected "\e[48;5;236m"

  def render(data, ui, opts \\ []) do
    width = max(Keyword.get(opts, :width, 160), 70)
    height = max(Keyword.get(opts, :height, 48), 20)

    header = header_rows(data, ui, width)
    footer = footer_rows(data, ui, width)
    body_height = max(height - length(header) - length(footer), 8)

    body =
      cond do
        width >= 150 -> wide_layout(data, ui, width, body_height)
        width >= 100 -> medium_layout(data, ui, width, body_height)
        true -> narrow_layout(data, ui, width, body_height)
      end

    (header ++ body ++ footer)
    |> Enum.take(height)
    |> Enum.join("\n")
  end

  defp header_rows(data, ui, width) do
    mode =
      case ui.mode do
        :search -> "SEARCH"
        :help -> "HELP"
        _ -> "LIVE"
      end

    health =
      data
      |> Map.get(:health, %{})
      |> Map.get(:summary, "status=unknown")

    line1 =
      apply_style(" HACKTUI // OPERATOR CONSOLE ", @fg_purple <> @bold) <>
        apply_style(" #{mode} ", @fg_cyan <> @bold)

    line2 =
      " updated=#{Map.get(data, :refreshed_at, "-")}" <>
        "  alerts=#{length(Map.get(data, :alerts, []))}" <>
        "  cases=#{length(Map.get(data, :cases, []))}" <>
        "  approvals=#{length(Map.get(data, :approvals, []))}" <>
        "  obs=#{length(Map.get(data, :observations, []))}" <>
        "  #{health}"

    [
      truncate_rendered(line1, width),
      apply_style(truncate_plain(line2, width), @fg_cyan),
      apply_style(String.duplicate("─", width), @fg_dim)
    ]
  end

  defp footer_rows(data, ui, width) do
    query =
      case ui.mode do
        :search -> " SEARCH> #{ui.pending_query}"
        _ -> " QUERY: #{ui.query}"
      end

    focus =
      " focus=#{ui.focused_pane}" <>
        "  row=#{Map.get(ui.selections, ui.focused_pane, 0) + 1}" <>
        "  hist=#{length(Map.get(data, :history, []))}"

    [
      apply_style(String.duplicate("─", width), @fg_dim),
      apply_style(truncate_plain(query <> focus, width), @fg_white),
      apply_style(
        truncate_plain(" q quit | tab cycle | j/k move | / search | enter apply | esc close ", width),
        @fg_base
      )
    ]
  end

  defp wide_layout(data, ui, width, body_height) do
    gap = 2
    usable = width - gap * 2

    left_w = 34
    right_w = 52
    center_w = max(usable - left_w - right_w, 46)

    total = left_w + center_w + right_w

    {left_w, center_w, right_w} =
      if total < usable do
        {left_w, center_w + (usable - total), right_w}
      else
        base = div(usable, 3)
        {base, base + rem(usable, 3), base}
      end

    left_body = body_height
    center_body = body_height
    right_body = body_height

    alerts_h = max(div(left_body * 2, 5), 7)
    cases_h = max(left_body - alerts_h - 1, 3)

    map_h = max(div(center_body * 2, 3), 10)
    summary_h = max(center_body - map_h - 1, 3)

    left_alerts =
      pane_box(
        "ALERT QUEUE",
        render_alert_lines(data, ui, left_w),
        left_w,
        alerts_h,
        ui.focused_pane == :alerts
      )

    left_cases =
      pane_box(
        "CASE BOARD",
        render_case_lines(data, ui, left_w),
        left_w,
        cases_h,
        ui.focused_pane == :cases
      )

    center_map =
      pane_box(
        "NETWORK MAP",
        render_network_map_lines(data, center_w),
        center_w,
        map_h,
        false
      )

    center_summary =
      pane_box(
        "NETWORK SUMMARY",
        render_network_summary_lines(data, center_w),
        center_w,
        summary_h,
        false
      )

    right_feed =
      pane_box(
        "LIVE TELEMETRY",
        render_observation_lines(data, ui, right_w),
        right_w,
        right_body,
        ui.focused_pane == :observations
      )

    left_stack = fit_stack([left_alerts, [""], left_cases], left_body, left_w)
    center_stack = fit_stack([center_map, [""], center_summary], center_body, center_w)
    right_stack = fit_stack([right_feed], right_body, right_w)

    Enum.zip([left_stack, center_stack, right_stack])
    |> Enum.map(fn {l, c, r} ->
      l <> String.duplicate(" ", gap) <> c <> String.duplicate(" ", gap) <> r
    end)
  end

  defp medium_layout(data, ui, width, body_height) do
    gap = 2
    left_w = max(div(width * 2, 5), 40)
    right_w = max(width - left_w - gap, 38)

    left_body = body_height
    right_body = body_height

    alerts_h = max(div(left_body, 4), 6)
    cases_h = max(div(left_body, 4), 6)
    map_h = max(left_body - alerts_h - cases_h - 2, 3)

    left_alerts =
      pane_box(
        "ALERT QUEUE",
        render_alert_lines(data, ui, left_w),
        left_w,
        alerts_h,
        ui.focused_pane == :alerts
      )

    left_cases =
      pane_box(
        "CASE BOARD",
        render_case_lines(data, ui, left_w),
        left_w,
        cases_h,
        ui.focused_pane == :cases
      )

    left_map =
      pane_box(
        "NETWORK MAP",
        render_network_map_lines(data, left_w),
        left_w,
        map_h,
        false
      )

    right_feed =
      pane_box(
        "LIVE TELEMETRY",
        render_observation_lines(data, ui, right_w),
        right_w,
        right_body,
        ui.focused_pane == :observations
      )

    left_stack = fit_stack([left_alerts, [""], left_cases, [""], left_map], left_body, left_w)
    right_stack = fit_stack([right_feed], right_body, right_w)

    Enum.zip(left_stack, right_stack)
    |> Enum.map(fn {l, r} -> l <> String.duplicate(" ", gap) <> r end)
  end

  defp narrow_layout(data, ui, width, body_height) do
    gap_rows = 1
    alerts_h = 6
    cases_h = 6
    map_h = 8
    feed_h = max(body_height - alerts_h - cases_h - map_h - gap_rows * 3, 8)

    alerts =
      pane_box(
        "ALERT QUEUE",
        render_alert_lines(data, ui, width),
        width,
        alerts_h,
        ui.focused_pane == :alerts
      )

    cases =
      pane_box(
        "CASE BOARD",
        render_case_lines(data, ui, width),
        width,
        cases_h,
        ui.focused_pane == :cases
      )

    netmap =
      pane_box(
        "NETWORK MAP",
        render_network_map_lines(data, width),
        width,
        map_h,
        false
      )

    feed =
      pane_box(
        "LIVE TELEMETRY",
        render_observation_lines(data, ui, width),
        width,
        feed_h,
        ui.focused_pane == :observations
      )

    fit_stack([alerts, [""], cases, [""], netmap, [""], feed], body_height, width)
  end

  defp fit_stack(parts, target_rows, width) do
    rows = List.flatten(parts)

    cond do
      length(rows) == target_rows -> rows
      length(rows) < target_rows -> pad_rendered_rows(rows, target_rows, width)
      true -> Enum.take(rows, target_rows)
    end
  end

  defp render_alert_lines(data, ui, width) do
    inner = max(width - 2, 1)
    focused = ui.focused_pane == :alerts
    selected_index = pane_selected_index(ui, :alerts)

    data
    |> Map.get(:alerts, [])
    |> Enum.reject(&seeded?/1)
    |> Enum.take(20)
    |> Enum.with_index()
    |> Enum.map(fn {alert, index} ->
      {plain, sev} = format_alert_row(alert, index, selected_index, focused, inner)
      style_row(plain, severity_color(sev), index == selected_index and focused, inner)
    end)
    |> blank_lines(" no alerts", @fg_base, inner)
  end

  defp format_alert_row(alert, index, selected_index, focused, width) do
    sev =
      alert
      |> Map.get(:severity, "info")
      |> to_string()
      |> String.upcase()

    title = Map.get(alert, :title) || "untitled alert"
    metadata = Map.get(alert, :metadata, %{}) || %{}

    actor =
      Map.get(metadata, "actor_label") ||
        Map.get(metadata, :actor_label)

    score =
      Map.get(metadata, "threat_score") ||
        Map.get(metadata, :threat_score)

    score_text =
      case score do
        nil -> "--"
        value when is_integer(value) -> String.pad_leading(Integer.to_string(value), 3)
        value when is_binary(value) -> String.pad_leading(value, 3)
        value -> value |> to_string() |> String.pad_leading(3)
      end

    actor_text =
      case actor do
        nil -> ""
        value -> "[#{String.upcase(to_string(value))}] "
      end

    marker = row_marker(index, selected_index, focused)

    cond do
      width >= 46 ->
        prefix = " #{marker} #{pad_plain(sev, 8)} TS:#{score_text} "
        tail = max(width - visible_length(prefix), 1)
        {prefix <> truncate_plain(actor_text <> title, tail), sev}

      width >= 28 ->
        prefix = " #{marker} #{pad_plain(sev, 8)} "
        tail = max(width - visible_length(prefix), 1)
        {prefix <> truncate_plain(actor_text <> title, tail), sev}

      true ->
        {" #{marker} " <> truncate_plain(actor_text <> title, max(width - 3, 1)), sev}
    end
  end

  defp render_case_lines(data, ui, width) do
    inner = max(width - 2, 1)
    focused = ui.focused_pane == :cases
    selected_index = pane_selected_index(ui, :cases)

    items =
      (Map.get(data, :cases, []) ++ Map.get(data, :approvals, []))
      |> Enum.reject(&seeded?/1)
      |> Enum.take(20)

    items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      title = Map.get(item, :title) || Map.get(item, :target) || "untitled case"
      marker = row_marker(index, selected_index, focused)
      prefix = " #{marker} "
      tail = max(inner - visible_length(prefix), 1)
      plain = prefix <> truncate_plain(title, tail)
      color = if focused, do: @fg_white, else: @fg_base
      style_row(plain, color, index == selected_index and focused, inner)
    end)
    |> blank_lines(" no active cases", @fg_base, inner)
  end

  defp render_observation_lines(data, ui, width) do
    inner = max(width - 2, 1)
    focused = ui.focused_pane == :observations
    selected_index = pane_selected_index(ui, :observations)

    data
    |> Map.get(:observations, [])
    |> Enum.filter(&interesting_observation?/1)
    |> Enum.take(100)
    |> Enum.with_index()
    |> Enum.map(fn {obs, index} ->
      {plain, sev, threat?} = format_observation_row(obs, index, selected_index, focused, inner)
      color = if threat?, do: @fg_purple <> @bold, else: severity_color(sev)
      style_row(plain, color, index == selected_index and focused, inner)
    end)
    |> blank_lines(" no observations", @fg_base, inner)
  end

  defp render_network_map_lines(data, width) do
    inner = max(width - 2, 1)
    flows = extract_flows(data)

    lines =
      cond do
        inner >= 64 -> detailed_network_map(flows, inner)
        inner >= 36 -> compact_network_map(flows, inner)
        true -> tiny_network_map(flows, inner)
      end

    lines
    |> blank_lines(" no network flows observed", @fg_dim, inner)
  end

  defp render_network_summary_lines(data, width) do
    inner = max(width - 2, 1)
    flows = extract_flows(data)

    hot_sites =
      flows
      |> Enum.filter(&(present?(&1.site)))
      |> Enum.frequencies_by(& &1.site)
      |> Enum.sort_by(fn {_k, v} -> -v end)
      |> Enum.take(4)

    hot_services =
      flows
      |> Enum.frequencies_by(& &1.service)
      |> Enum.sort_by(fn {_k, v} -> -v end)
      |> Enum.take(4)

    top_dests =
      flows
      |> Enum.frequencies_by(&destination_label/1)
      |> Enum.sort_by(fn {_k, v} -> -v end)
      |> Enum.take(4)

    lines =
      [
        " flows=#{length(flows)}",
        " unique_src=#{flows |> Enum.map(& &1.src) |> Enum.uniq() |> length()}",
        " unique_dst=#{flows |> Enum.map(& &1.dst) |> Enum.uniq() |> Enum.reject(&is_nil/1) |> length()}",
        ""
      ] ++
        [" hot sites:"] ++
        Enum.map(hot_sites, fn {site, count} -> "  #{truncate_plain(site, max(inner - 8, 1))} x#{count}" end) ++
        ["", " services:"] ++
        Enum.map(hot_services, fn {service, count} -> "  #{truncate_plain(to_string(service), max(inner - 8, 1))} x#{count}" end) ++
        ["", " destinations:"] ++
        Enum.map(top_dests, fn {label, count} -> "  #{truncate_plain(label, max(inner - 8, 1))} x#{count}" end)

    lines
    |> Enum.map(&apply_style(truncate_plain(&1, inner), @fg_base))
    |> blank_lines(" no network summary", @fg_dim, inner)
  end

  defp detailed_network_map([], _inner), do: []

  defp detailed_network_map(flows, inner) do
    flows
    |> aggregate_flows()
    |> Enum.take(10)
    |> Enum.flat_map(fn row ->
      left = truncate_plain(source_label(row), 18)
      right = truncate_plain(destination_label(row), max(inner - 36, 6))
      service = row.service || "FLOW"
      sev_dot = severity_dot(row.severity)
      count = "x#{row.count}"

      [
        " " <> sev_dot <> " " <> pad_plain(left, 18) <> apply_style(" ─┐", @fg_cyan),
        " " <> String.duplicate(" ", 20) <> apply_style(" ├─> ", @fg_cyan) <>
          truncate_rendered("#{service} → #{right} #{count}", max(inner - 26, 1))
      ]
    end)
  end

  defp compact_network_map([], _inner), do: []

  defp compact_network_map(flows, inner) do
    flows
    |> aggregate_flows()
    |> Enum.take(12)
    |> Enum.map(fn row ->
      sev_dot = severity_dot(row.severity)
      left = source_label(row)
      right = destination_label(row)
      service = row.service || "FLOW"
      text = " #{sev_dot} #{left} -> #{right}  #{service} x#{row.count}"
      truncate_rendered(text, inner)
    end)
  end

  defp tiny_network_map([], _inner), do: []

  defp tiny_network_map(flows, inner) do
    flows
    |> aggregate_flows()
    |> Enum.take(6)
    |> Enum.map(fn row ->
      sev_dot = severity_dot(row.severity)
      truncate_rendered(" #{sev_dot} #{destination_label(row)} x#{row.count}", inner)
    end)
  end

  defp format_observation_row(obs, index, selected_index, focused, width) do
    metadata = Map.get(obs, :metadata, %{}) || %{}
    payload = Map.get(obs, :payload, %{}) || %{}

    time =
      case Map.get(metadata, :occurred_at) || Map.get(obs, :accepted_at) do
        %DateTime{} = dt -> Calendar.strftime(dt, "%H:%M:%S")
        ts when is_binary(ts) -> String.slice(ts, 11, 8)
        _ -> "00:00:00"
      end

    sev =
      (Map.get(metadata, :severity) || Map.get(payload, "severity") || "INFO")
      |> to_string()
      |> String.upcase()

    kind =
      obs
      |> Map.get(:kind, "unknown")
      |> to_string()

    summary = observation_summary(obs, payload)

    threat_context = Map.get(metadata, :threat_context) || Map.get(metadata, "threat_context")
    threat? = not is_nil(threat_context)
    marker = if threat?, do: "!", else: row_marker(index, selected_index, focused)

    cond do
      width >= 48 ->
        prefix = " #{marker} #{time} #{pad_plain(sev, 6)} #{truncate_plain(kind, 16)} "
        tail = max(width - visible_length(prefix), 1)
        {prefix <> truncate_plain(summary, tail), sev, threat?}

      width >= 28 ->
        prefix = " #{marker} #{time} #{pad_plain(sev, 6)} "
        tail = max(width - visible_length(prefix), 1)
        {prefix <> truncate_plain(summary, tail), sev, threat?}

      true ->
        {" #{marker} " <> truncate_plain(summary, max(width - 3, 1)), sev, threat?}
    end
  end

  defp observation_summary(obs, payload) do
    kind = to_string(Map.get(obs, :kind, ""))

    cond do
      kind == "network.flow" ->
        src = PrivacyMask.mask(Map.get(payload, "src")) || "?"
        dst = PrivacyMask.mask(Map.get(payload, "dst")) || "?"
        site = normalize_blank(Map.get(payload, "site"))
        service = Map.get(payload, "service") || "FLOW"
        src_port = Map.get(payload, "src_port")
        dst_port = Map.get(payload, "dst_port")

        base =
          "#{service} #{src}" <>
            if(src_port, do: ":#{src_port}", else: "") <>
            " -> " <>
            if(site, do: "#{site} ", else: "") <>
            "#{dst}" <>
            if(dst_port, do: ":#{dst_port}", else: "")

        info = Map.get(payload, "info")
        if present?(info), do: base <> " | " <> to_string(info), else: base

      true ->
        Map.get(payload, "summary") ||
          Map.get(payload, :summary) ||
          inspect(Map.take(payload, ["summary", "src", "dst"]))
    end
  end

  defp extract_flows(data) do
    data
    |> Map.get(:observations, [])
    |> Enum.map(&normalize_flow/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&loopback_flow?/1)
  end

  defp normalize_flow(obs) do
    payload = Map.get(obs, :payload, %{}) || %{}
    kind = obs |> Map.get(:kind, "") |> to_string()
    summary = Map.get(payload, "summary") || Map.get(payload, :summary) || ""

    raw_src =
      Map.get(payload, "src") ||
        Map.get(payload, :src) ||
        Map.get(payload, "source_ip") ||
        Map.get(payload, :source_ip)

    raw_dst =
      Map.get(payload, "dst") ||
        Map.get(payload, :dst) ||
        Map.get(payload, "destination_ip") ||
        Map.get(payload, :destination_ip)

    src = if is_binary(raw_src), do: PrivacyMask.mask(raw_src), else: raw_src
    dst = if is_binary(raw_dst), do: PrivacyMask.mask(raw_dst), else: raw_dst

    proto =
      Map.get(payload, "proto") ||
        Map.get(payload, :proto) ||
        protocol_from_summary(summary)

    service =
      Map.get(payload, "service") ||
        Map.get(payload, :service) ||
        proto ||
        kind

    severity =
      Map.get(payload, "severity") ||
        Map.get(payload, :severity) ||
        Map.get(obs, :severity) ||
        "info"

    site =
      Map.get(payload, "site") ||
        Map.get(payload, :site) ||
        Map.get(payload, "dst_host") ||
        Map.get(payload, :dst_host) ||
        Map.get(payload, "http_host") ||
        Map.get(payload, :http_host) ||
        Map.get(payload, "tls_sni") ||
        Map.get(payload, :tls_sni) ||
        Map.get(payload, "dns_question") ||
        Map.get(payload, :dns_question)

    src_port =
      Map.get(payload, "src_port") ||
        Map.get(payload, :src_port)

    dst_port =
      Map.get(payload, "dst_port") ||
        Map.get(payload, :dst_port)

    cond do
      is_binary(src) and is_binary(dst) ->
        %{
          src: src,
          dst: dst,
          proto: to_string(proto || kind || "?"),
          service: to_string(service || "FLOW"),
          severity: to_string(severity || "info"),
          site: normalize_blank(site),
          src_port: src_port,
          dst_port: dst_port
        }

      kind == "network.flow" ->
        case parse_flow_summary(summary, proto || "FLOW") do
          nil ->
            nil

          row ->
            masked_row = %{
              src: if(is_binary(row.src), do: PrivacyMask.mask(row.src), else: row.src),
              dst: if(is_binary(row.dst), do: PrivacyMask.mask(row.dst), else: row.dst),
              proto: row.proto
            }

            Map.merge(masked_row, %{
              service: to_string(service || "FLOW"),
              severity: to_string(severity || "info"),
              site: normalize_blank(site),
              src_port: src_port,
              dst_port: dst_port
            })
        end

      true ->
        nil
    end
  end

  defp parse_flow_summary(summary, proto) when is_binary(summary) do
    case Regex.run(~r/(\d{1,3}(?:\.\d{1,3}){3})\s*->\s*(\d{1,3}(?:\.\d{1,3}){3})/, summary) do
      [_, src, dst] ->
        %{src: src, dst: dst, proto: to_string(proto || "?")}

      _ ->
        nil
    end
  end

  defp parse_flow_summary(_, _), do: nil

  defp protocol_from_summary(summary) when is_binary(summary) do
    case Regex.run(~r/\[([A-Za-z0-9]+)\]/, summary) do
      [_, proto] -> String.upcase(proto)
      _ -> nil
    end
  end

  defp protocol_from_summary(_), do: nil

  defp aggregate_flows(flows) do
    flows
    |> Enum.group_by(fn f ->
      {f.src, f.dst, f.site, f.service, f.severity}
    end)
    |> Enum.map(fn {{src, dst, site, service, severity}, entries} ->
      first = hd(entries)

      %{
        src: src,
        dst: dst,
        site: site,
        service: service,
        severity: severity,
        proto: first.proto,
        src_port: first.src_port,
        dst_port: first.dst_port,
        count: length(entries)
      }
    end)
    |> Enum.sort_by(fn row -> {-severity_rank(row.severity), -row.count, row.service || "", row.dst || ""} end)
  end

  defp severity_rank(sev) do
    case String.downcase(to_string(sev)) do
      "critical" -> 4
      "high" -> 3
      "medium" -> 2
      "low" -> 1
      _ -> 0
    end
  end

  defp source_label(row), do: row.src

  defp destination_label(row) do
    site = normalize_blank(row.site)

    base =
      cond do
        present?(site) -> "#{site} #{row.dst}"
        true -> row.dst
      end

    if row.dst_port do
      "#{base}:#{row.dst_port}"
    else
      base
    end
  end

  defp severity_dot(sev) do
    dot = "●"

    case String.downcase(to_string(sev)) do
      "critical" -> apply_style(dot, @fg_red <> @bold)
      "high" -> apply_style(dot, @fg_red <> @bold)
      "medium" -> apply_style(dot, @fg_yellow <> @bold)
      "low" -> apply_style(dot, @fg_green <> @bold)
      _ -> apply_style(dot, @fg_base)
    end
  end

  defp loopback_flow?(%{src: src, dst: dst}) do
    loopback?(src) and loopback?(dst)
  end

  defp loopback_flow?(_), do: false

  defp loopback?(nil), do: false
  defp loopback?(ip), do: String.starts_with?(ip, "127.") or ip == "::1" or ip == "[LOCAL_HOST]"

  defp interesting_observation?(obs) do
    case to_string(Map.get(obs, :kind, "")) do
      "process_signals" -> false
      _ -> true
    end
  end

  defp seeded?(item) do
    item
    |> Map.get(:metadata, %{})
    |> case do
      %{} = meta -> Map.get(meta, "seeded") == true or Map.get(meta, :seeded) == true
      _ -> false
    end
  end

  defp pane_box(title, lines, width, height, focused?) do
    total_width = max(width, 4)
    inner_width = max(total_width - 2, 1)
    total_height = max(height, 3)
    content_height = max(total_height - 2, 1)

    title_text =
      if focused? do
        " #{title} * "
      else
        " #{title} "
      end

    title_bar =
      title_text
      |> truncate_plain(inner_width)
      |> String.pad_trailing(inner_width, "─")

    top = "┌" <> apply_style(title_bar, @fg_purple <> @bold) <> "┐"

    middle =
      lines
      |> Enum.take(content_height)
      |> pad_content_lines(content_height)
      |> Enum.map(fn line ->
        clipped = truncate_rendered(line, inner_width)
        pad_count = max(inner_width - visible_length(clipped), 0)
        "│" <> clipped <> String.duplicate(" ", pad_count) <> "│"
      end)

    bottom = "└" <> String.duplicate("─", inner_width) <> "┘"
    [top | middle] ++ [bottom]
  end

  defp pad_content_lines(lines, target) do
    lines ++ List.duplicate("", max(target - length(lines), 0))
  end

  defp pad_rendered_rows(rows, target, width) do
    blank = String.duplicate(" ", max(width, 1))
    rows ++ List.duplicate(blank, max(target - length(rows), 0))
  end

  defp blank_lines([], text, color, width), do: [style_row(" #{text}", color, false, width)]
  defp blank_lines(rows, _text, _color, _width), do: rows

  defp severity_color(sev) do
    case String.downcase(to_string(sev)) do
      "critical" -> @fg_red <> @bold
      "high" -> @fg_red <> @bold
      "medium" -> @fg_yellow <> @bold
      "low" -> @fg_green
      _ -> @fg_base
    end
  end

  defp row_marker(i, s, f) when i == s and f, do: "›"
  defp row_marker(_, _, _), do: "•"

  defp pane_selected_index(ui, pane), do: ui |> Map.get(:selections, %{}) |> Map.get(pane, 0)

  defp style_row(text, color, selected?, width) do
    clipped =
      text
      |> truncate_plain(width)
      |> String.pad_trailing(width)

    row_color = if selected?, do: @bg_selected <> color, else: color
    apply_style(clipped, row_color)
  end

  defp apply_style(text, color), do: color <> text <> @reset

  defp truncate_plain(_text, width) when width <= 0, do: ""
  defp truncate_plain(text, width), do: text |> to_string() |> String.slice(0, width)

  defp truncate_rendered(_text, width) when width <= 0, do: ""
  defp truncate_rendered("", _width), do: ""

  defp truncate_rendered(text, width) do
    text
    |> to_string()
    |> take_visible(width, "")
  end

  defp take_visible("", _remaining, acc), do: acc
  defp take_visible(_text, remaining, acc) when remaining <= 0, do: acc

  defp take_visible(<<"\e[", rest::binary>>, remaining, acc) do
    {ansi, tail} = take_ansi_sequence(rest, "\e[")
    take_visible(tail, remaining, acc <> ansi)
  end

  defp take_visible(<<char::utf8, rest::binary>>, remaining, acc) do
    take_visible(rest, remaining - 1, acc <> <<char::utf8>>)
  end

  defp take_ansi_sequence(<<>>, acc), do: {acc, ""}

  defp take_ansi_sequence(<<char::utf8, rest::binary>>, acc) do
    next = acc <> <<char::utf8>>

    if ansi_terminator?(char) do
      {next, rest}
    else
      take_ansi_sequence(rest, next)
    end
  end

  defp ansi_terminator?(char) when char >= ?A and char <= ?Z, do: true
  defp ansi_terminator?(char) when char >= ?a and char <= ?z, do: true
  defp ansi_terminator?(_), do: false

  defp visible_length(text) do
    text
    |> to_string()
    |> String.replace(~r/\e\[[0-9;?]*[A-Za-z]/, "")
    |> String.length()
  end

  defp pad_plain(value, width) do
    value
    |> to_string()
    |> truncate_plain(width)
    |> String.pad_trailing(width)
  end

  defp normalize_blank(nil), do: nil

  defp normalize_blank(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      other -> other
    end
  end

  defp present?(nil), do: false
  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: true
end
