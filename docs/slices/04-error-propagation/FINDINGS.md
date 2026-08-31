# Slice 04 — FINDINGS

## F1 — The MCP transport crash, reproduced and fixed

Two independent audits found this; neither `mix credo --strict` nor `mix dialyzer`
catches it, so no gate in CLAUDE.md section 4 would have.

```
$ m = %{collector: :packet_capture}
  buggy: Map.get(m, :collector) || ... || "" |> to_string() |> String.downcase()
      -> :packet_capture                          # pipeline applied only to ""
  fixed: (Map.get(m, :collector) || ... || "") |> to_string() |> String.downcase()
      -> "packet_capture"
  String.contains? on buggy raises: FunctionClauseError
  String.contains? on fixed works:  false
```

Collectors set `collector: :packet_capture` at `collectors/network.ex:315` and
`hacktui_sensor.ex:104,255`. `normalize_observation_event/1` preserves the atom. There is
no rescue in `Dispatch.call/3`, `Server.handle_message/2` or `Stdio.loop/1`, so the
exception ended the client's session.

Fixed by parenthesising the `||` chain, and defence-in-depth via `Dispatch.safe_call/3`:

```
  safe_call returned: {:error, %{reason: "function ... is undefined", tool: ...}}
  process still alive: true
```

## F2 — Failures rendered as emptiness

`safe_all_query/2` backed `alert_queue/1`, `case_board/1`, `approval_inbox/1`,
`audit_events/1` and `case_timeline/2`, and returned `[]` on any exception or exit. The
module's own moduledoc asserted the opposite:

> "no hidden rescue path that turns real alerts into an empty queue"

Now `query_all/2` returns `{:ok, rows} | {:error, reason}`; the list-returning wrapper
logs and records the failure; `live_dashboard_snapshot/2` exposes `:degraded`; and the TUI
renders a red banner. Proven by test:

```
a failing repo is recorded as a failure, not an empty result       PASS
a genuinely empty table records no failure                          PASS
the dashboard snapshot distinguishes empty from unreadable          PASS
an unavailable repo module is a failure, not silence                PASS
```

## F3 — Six `with` blocks leaked a 4-tuple in violation of every `@spec`

`create_alert`, `transition_alert`, `open_case`, `transition_case`, `request_action` and
`record_audit` all `with`-matched `{:ok, ...}` with no `else`. On a persistence failure
`HacktuiStore` returns `{:error, step, reason, changes}`, which fell straight through to
the caller. `Forwarder.normalize_rpc_result/1` has a catch-all
`normalize_rpc_result(other), do: {:ok, other}` — so a persistence failure arrived at the
sensor as **success**. Each now normalises to `{:error, {step, reason}}`.

## Gate results

| Gate | Before | After |
|---|---|---|
| test failures | 7 | **7** (held; 133 → 140 tests) |
| credo | 77 | **77** (held) |
| dialyzer | 44 | **43** — baseline lowered |
