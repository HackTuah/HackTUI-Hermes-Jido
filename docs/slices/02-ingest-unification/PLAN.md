# Slice 02 — ingest-unification

**Branch:** `slice/02-ingest-unification`
**Status:** implemented; review batched to the end of the slice run per maintainer direction
**Depends on:** slice 01 (gates), commit `563b26c`

## Why

`HacktuiHub.Runtime.accept_observation/2` (`runtime.ex:42-74`) is the only function that
persists an observation, records an audit event, derives an alert, scores threat,
correlates/dedups, and opens a case. **It has zero production callers.**

```
$ grep -rn "Runtime.accept_observation" apps/ --include=*.ex
apps/hacktui_hub/lib/hacktui_hub/runtime.ex:42:  def accept_observation(attrs, opts \\ []) ...
```

Every live path calls `IngestService.accept_observation/2` instead:

| Caller | Line | Goes to |
|---|---|---|
| `HacktuiSensor.Forwarder` | `forwarder.ex:129-133` | `IngestService` |
| `HacktuiHub.Replay.Runner` | `replay/runner.ex:65` | `IngestService` |
| `HacktuiHub.QueryService` | `query_service.ex:155` | `IngestService` |

`IngestService.accept_observation/2` (`ingest_service.ex:15-38`) runs the pure `Ingest`
handler and inserts into `IngestBuffer` — a **100-slot in-memory ring buffer**. No repo
write. No audit event.

**Consequence:** the `alerts`, `audit_events`, `cases`, and `alert_transitions` tables
only ever contain `DemoSeed` rows. Live telemetry is lost on restart. Roughly 500 of
`runtime.ex`'s 938 lines are unreachable. The audit trail claimed in `README.md:148`,
`PROJECT_BRIEF.md:91-105`, and `THREAT_MODEL.md` **does not exist for live operation**.

### The complication that makes this more than a one-line caller swap

`Runtime.accept_observation/2` calls `DetectionService.derive_alert/2`, which is a bare
delegate (`detection_service.ex:9`) to `Alerting.handle/2`, which does:

```elixir
# apps/hacktui_core/lib/hacktui_core/command_handlers/alerting.ex:19
alert_id: Map.fetch!(payload, "alert_id"),
```

**No live sensor payload contains `alert_id`** — verified across
`collectors/network.ex:284-302`, `hacktui_sensor.ex:246-253`, and `:129-137`. Only the
replay fixture has it (`fixtures/replay/case-1.jsonl`). So simply repointing `Forwarder`
at `Runtime` raises `KeyError` on **every** live observation.

The deeper finding: **there is no detection.** `derive_alert` unconditionally converts an
observation into an alert and requires the payload to pre-declare its own alert id. It is
a fixture-shaped converter, not a detector. Nothing decides *whether* an observation
warrants an alert.

## The design decision this slice must make

Not every observation should become an alert — a routine DNS lookup is not an incident.
Ingest and detection must separate:

```
observation → audit event (always persisted)
            → detection predicate → alert (only when warranted, with a derived id)
                                  → correlate/dedup → threat score → maybe open case
```

**Recommended predicate for this slice** — deliberately minimal and honest, built only
from signals that already exist:

- promote when normalised severity is `:high` or `:critical`
  (live observations already carry severity: `network.ex:301`, `hacktui_sensor.ex:244`)
- promote when the payload carries an explicit `alert_id` (preserves replay behaviour)
- otherwise persist the audit event and stop

`threat_score/2` (`runtime.ex:302-320`) already weighs severity plus kind
(`journald.security` +18, `network.flow` +12, `system.error` +10), and
`should_open_case?/3` (`runtime.ex:672-674`) already gates on
`severity in [:critical, :high] or threat_score >= threshold`. This predicate is
consistent with both and adds no new tuning knobs.

Threat-intel-driven promotion is deliberately **excluded** — that subsystem is dead until
slice 06 (`Indexer` is in no supervision tree; `threat_context` has three incompatible
shapes). Adding it here would build on a broken foundation.

## In scope

1. Split ingest from detection. Add a detection predicate that decides promotion and
   **derives** a deterministic `alert_id` from the observation, rather than requiring the
   payload to carry one.
2. Make `Alerting.handle/2` return `{:error, :missing_alert_id}` instead of raising
   `KeyError`, so malformed input is rejected rather than crashing the caller.
3. Route `Forwarder` (`forwarder.ex:129`), `Replay.Runner` (`runner.ex:65`), and
   `QueryService` (`query_service.ex:155`) through the unified persisting path.
4. Degrade honestly when the repo is not started (the default is
   `HACKTUI_START_REPO=false`): return a result that says persistence was skipped. Never
   crash, and never silently claim a write happened.
5. End-to-end test: a sensor observation produces an `audit_events` row; a high-severity
   observation additionally produces an `alerts` row; a low-severity one does not.
6. Unit tests for the predicate and for the derived-id determinism.

## Out of scope (section 9)

- The `with` blocks in `runtime.ex` that leak `{:error, name, term, changes}` — slice 04.
- `safe_all_query/2` swallowing DB errors — slice 04.
- Correlation lost-update races, missing constraints/indexes — slice 05.
- ThreatIntel — slice 06.
- Supervising `IngestBuffer` / `Indexer` — slice 03.
- The MCP transport crash — slice 04.

Discoveries go to `BACKLOG.md`.

## Risks

- **The 18 `:integration` tests have never run in CI** and need a live PostgreSQL. This
  slice's end-to-end test is DB-backed, so it will be `:integration`-tagged and must be
  run explicitly. Local verification requires `HACKTUI_DB_PASS` and a migrated database.
- Routing live telemetry into the repo means the sensor's ~50 observations/sec now hit
  PostgreSQL. Write volume and the unbounded-query problem (slice 05) become live
  concerns. Mitigation: the collectors default to enabled today — slice 03 changes that —
  so this slice should be verified with the sensor **off** and observations injected
  explicitly.

## Acceptance criteria

- [x] Only `runtime.ex` calls `IngestService.accept_observation` — asserted by a test.
- [x] A sensor-shaped observation with no `alert_id` flows without raising.
- [ ] `audit_events` gains a row per accepted observation — **not verified against a
      live database**; the assertion is `:integration`-tagged and those tests have never
      run in CI. Logged in BACKLOG.
- [ ] Same: predicate is unit-tested, DB effect is not yet verified.
- [x] Repo stopped → `persistence: :skipped_no_repo`, no raise.
- [x] Superseded: ids are now *derived*, so there is no un-derivable payload. Empty
      `alert_id` falls back to the derived form rather than erroring.
- [x] test 7 (held), credo 77 (held), dialyzer 61 → **44**, baseline lowered.
- [ ] Fresh-context review — batched to the end of the slice run per maintainer direction.

## Verification

```bash
# unit
mix test apps/hacktui_core/test apps/hacktui_hub/test

# end to end, DB-backed
export HACKTUI_DB_PASS=... HACKTUI_START_REPO=true HACKTUI_DB_NAME=hacktui_qualification_test
mix ecto.migrate
mix test --include integration apps/hacktui_hub/test

# the claim this slice exists to make true
iex -S mix
  HacktuiHub.Runtime.accept_observation(%{...sensor-shaped, no alert_id...})
  HacktuiStore.Repo.aggregate(HacktuiStore.Schema.AuditEvent, :count)   # > 0
```
