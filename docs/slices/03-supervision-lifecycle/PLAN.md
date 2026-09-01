# Slice 03 — supervision-lifecycle

**Branch:** `slice/03-supervision-lifecycle`
**Status:** implemented; review batched to the end of the slice run per maintainer direction
**Depends on:** slice 02 (`049c57d`)

## Why

Processes the system depends on were never supervised, and the sensor could not boot as
its own release.

## In scope / done

1. **`IngestBuffer` supervised.** Was started lazily by `IngestService` via
   `GenServer.start/3` — unlinked, outside any tree, state silently lost on crash and
   re-created empty on next use.
2. **`ThreatIntel.Indexer` supervised.** Was in **no** supervision tree, so
   `:threat_intel_keywords` never existed and `lookup/1` raised on every observation,
   swallowed by a blanket `rescue` in `IngestService`.
3. **Collectors are opt-in.** Both defaulted to enabled, so launching the MCP server
   started `tshark -i any` and `journalctl --follow` on the host as a side effect — the
   mix task starts every umbrella app. Now `HACKTUI_SENSOR_NETWORK=1` /
   `HACKTUI_SENSOR_JOURNALD=1`.
4. **Sensor declares `hacktui_hub`.** Its `.app` omitted it while `Forwarder` called into
   it, so the standalone release died at boot under restart intensity.
5. **`config/runtime.exs` prod guard is release-safe.** It called
   `HacktuiStore.RuntimeConfig`, which is not in the sensor release, so
   `hacktui_sensor start` raised before the tree started.
6. **Network collector backoff.** Rescheduled every 2s forever; with tshark absent or
   lacking `CAP_NET_RAW` that emitted a high-severity `system.error` observation every 2
   seconds indefinitely — which, now that ingest persists, would also flood
   `audit_events`. Now exponential with a 60s cap and a hard stop after 5 consecutive
   failures with one summary observation.
7. **`journalctl` resolved at runtime.** As a module attribute it baked the build host's
   filesystem into the release; a container without systemd got `nil` permanently, with
   no diagnostic. Dialyzer had proven the resulting `is_nil/1` guard dead.
8. **`handle_info` catch-alls log.** **RETRACTED (slice 08):** two of three, not all
   three. `Collectors.ProcessSignals` had no catch-all at all, so an unmatched message
   raised `FunctionClauseError` and killed the collector rather than being "silently
   dropped". Fixed in slice 07.

## Out of scope (section 9)

Error propagation and the MCP transport crash (slice 04); data integrity (05);
ThreatIntel behaviour (06). Discoveries logged to `BACKLOG.md`.

## Verification

```bash
mix run --no-halt -e 'Application.ensure_all_started(:hacktui_hub);
  IO.inspect({Process.whereis(HacktuiHub.IngestBuffer),
              Process.whereis(HacktuiHub.ThreatIntel.Indexer),
              :ets.whereis(:threat_intel_keywords)})'
grep -o "{applications,\[[^]]*\]}" _build/dev/lib/hacktui_sensor/ebin/hacktui_sensor.app
```
