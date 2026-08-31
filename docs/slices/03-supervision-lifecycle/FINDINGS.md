# Slice 03 — FINDINGS

## F1 — Two processes the system depends on were never supervised

- `IngestBuffer`: started by `IngestService` via `GenServer.start/3` (not `start_link`),
  lazily, outside any tree. Unlinked, no restart policy, state lost silently on crash.
- `ThreatIntel.Indexer`: in **no** supervision tree. Its named ETS table was created in
  `init/1`, which never ran, so `lookup/1` raised `ArgumentError` on every observation —
  swallowed by a blanket `rescue _` in `IngestService`.

Both are now children of `HacktuiHub.Supervisor`. Verified:
```
IngestBuffer: #PID<0.345.0>
Indexer:      #PID<0.346.0>
ETS table:    #Reference<0.5297246.4276224006.72257>
```
The ETS table has existed for the first time in the project's history.

## F2 — `actor` is a string, and the audit path assumed a struct

Surfaced immediately once slice 02 routed live telemetry into persistence:
```
** (BadMapError) expected a map, got: "hacktui_sensor"
    (hacktui_store) lib/hacktui_store/audits.ex:23: HacktuiStore.Audits.audit_changeset/1
    (hacktui_hub)   lib/hacktui_hub/runtime.ex:65: HacktuiHub.Runtime.persist_accepted_observation/3
```
Collectors set `actor: "hacktui_sensor"` (a binary); `audit_changeset/1` does
`event.actor.id`. Every live observation would have crashed `Forwarder`, taking the
sensor's supervisor down with it. Fixed by normalising to an `%ActorRef{}` at the
boundary.

This is a defect slice 02 could not have found without slice 03's routing being exercised
under a running repo — the two slices together are what made it visible.

## F3 — Launching MCP started host-wide packet capture

`network_enabled` and `journald_enabled` both defaulted to `true`, and
`mix hacktui.mcp` starts every umbrella app. Any MCP client connecting therefore spawned
`tshark -i any` and `journalctl --follow` on the operator's host. Now opt-in via
`HACKTUI_SENSOR_NETWORK` / `HACKTUI_SENSOR_JOURNALD`.

## F4 — The sensor release could not boot

Two independent causes:
1. `apps/hacktui_sensor/mix.exs` declared only `hacktui_core`, but `Forwarder` calls
   `HacktuiHub.Runtime`. The generated `.app` omitted `hacktui_hub`, so the standalone
   release raised `UndefinedFunctionError` inside `handle_call` and, at ~50 obs/sec,
   exceeded `:one_for_one` restart intensity in well under a second.
2. `config/runtime.exs` called `HacktuiStore.RuntimeConfig`, which is not in the sensor
   release, and is evaluated by the release config provider before the tree starts.

Both fixed. `hacktui_sensor.app` now lists `hacktui_hub`.

## F5 — Unbounded error storm on capture failure

`network.ex` rescheduled `:start_capture` every 2s forever. With `tshark` absent or
lacking `CAP_NET_RAW` — the common case for a non-root operator — that emitted a
high-severity `system.error` observation every 2 seconds indefinitely. After slice 02
those observations persist, so this would also have flooded `audit_events`. Now
exponential backoff capped at 60s, with a hard stop after 5 consecutive failures and a
single summary observation.

## F6 — Two dead conditionals proven by dialyzer

`build_summary/8` did `if(site, ...)` and `if(service, ...)` where both are always
binaries, so the `else` branches were unreachable:
```
{:guard_fail, [~c"_@23::binary()", ~c"=:=", ~c"'nil'"]}
```
Comparing against `""` instead is type-correct and expresses the real intent. Found only
because the ratchet blocked a +1 dialyzer regression.

## Gate results

| Gate | Before | After |
|---|---|---|
| test failures | 7 | **7** (held; 130 → 133 tests) |
| credo | 77 | **77** (held) |
| dialyzer | 44 | **44** (held) |

Two regressions were caught and fixed by the ratchet during this slice: a `cond` with a
single condition (credo 78) and the F6 dead conditionals (dialyzer 45). Neither would
have been noticed without the gate.
