# Slice 02 — FINDINGS

## F1 — `Runtime.accept_observation/2` had zero production callers

- **Location:** `apps/hacktui_hub/lib/hacktui_hub/runtime.ex:42`
- **Observed:** the only function that persists an observation, audits it, derives an
  alert, scores threat, correlates and opens a case was called by nothing.
  ```
  $ grep -rn "Runtime.accept_observation" apps/ --include=*.ex
  apps/hacktui_hub/lib/hacktui_hub/runtime.ex:42:  def accept_observation(attrs, opts \\ [])
  ```
  Every live path used `IngestService.accept_observation/2`, which fills a 100-slot RAM
  ring buffer and touches no repo.
- **Fix:** `Forwarder` (`forwarder.ex:90`), `Replay.Runner` (`runner.ex:65`) and
  `QueryService` (`query_service.ex:155`) now route through `Runtime`. A regression test
  asserts `IngestService.accept_observation` has exactly one caller.

## F2 — The path could not have worked if it had been called

Three independent defects, each fatal on the first live observation:

1. **`Map.fetch!(payload, "alert_id")`** — `alerting.ex:19`. No sensor payload carries
   that key; only replay fixtures do. Every live observation would raise `KeyError`.
2. **`Audits.persist(repo, accepted)`** — `runtime.ex:51` passed an
   `%ObservationAccepted{}` to a function whose only clause matches `%AuditRecorded{}`:
   ```
   $ grep -n "def persist" apps/hacktui_store/lib/hacktui_store/audits.ex
   11:  def persist(repo, %AuditRecorded{} = event) do
   ```
   A guaranteed `FunctionClauseError`.
3. **No repo guard** — the default runtime is `HACKTUI_START_REPO=false`, so the first
   `repo.transaction/1` would fail with the repo not started.

All three are fixed: ids are derived, a real `AuditRecorded` is built, and
`repo_available?/1` gates persistence.

## F3 — There was no detection

`DetectionService` (`detection_service.ex:9`) is a bare `defdelegate` to
`Alerting.handle/2`, which converted **every** observation into an alert. Nothing decided
whether an observation warranted one. That is why it worked on a two-line fixture and
would have exploded on real telemetry.

Added `HacktuiCore.Detection` — a pure predicate. Promotes on normalised severity
`:high`/`:critical`, or an explicit `alert_id` (preserving replay). Consistent with
`threat_score/2` and `should_open_case?/3` downstream. Threat-intel promotion is
deliberately excluded: that subsystem is dead until slice 06.

## F4 — Metadata normalisation destroyed the caller's keys

- **Location:** `runtime.ex`, `normalize_metadata_map/1` → `stringify_top_level_keys_to_atoms/1`
- **Observed:** every string key was run through `String.to_existing_atom/1`, so a replay
  fixture's `metadata["sequence"]` silently became `metadata[:sequence]`:
  ```
  assert Enum.map(accepted, & &1.metadata["sequence"]) == [1, 2]
  left:  [nil, nil]
  ```
  Surfaced only once replay was routed through `Runtime`. Normalisation should add the
  derived `threat_context`, not rewrite the caller's data.
- **Fix:** keys are preserved; only `:threat_context` is added.
  `stringify_top_level_keys_to_atoms/1` is now dead and removed.

## Gate results

| Gate | Before | After |
|---|---|---|
| test failures | 7 | **7** (held; 115 → 130 tests) |
| credo | 77 | **77** (held) |
| dialyzer | 61 | **44** — baseline lowered |

The dialyzer improvement is a direct consequence of F2 and F4: removing the dead
converter and fixing the two type mismatches eliminated 17 warnings.

## Still true after this slice

Live telemetry now reaches PostgreSQL **when a repo is running**. It is not yet verified
end to end against a live database — the DB-backed assertion is `:integration`-tagged and
those 18 tests have never run in CI. Recorded in `BACKLOG.md`.
