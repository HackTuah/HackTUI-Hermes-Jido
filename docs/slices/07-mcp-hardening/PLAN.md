# Slice 07 — mcp-hardening

**Branch:** `slice/07-mcp-hardening`
**Status:** implemented
**Depends on:** slice 06 follow-up (`25f9764`)

## Why

Two independent batched reviewers (security lens, correctness/OTP lens) both returned
**FAIL** on slices 02–06 and found five defects that the earlier slices introduced.

## In scope / done

1. **C1 — a database outage killed the sensor.** `repo_available?/1` tested
   `Process.whereis(repo)`; an `Ecto.Repo` supervisor is registered whether or not the
   database is reachable, so `repo.transaction/1` raised. There was no rescue anywhere in
   `accept_observation → persist_accepted_observation → Audits.persist`, so the raise
   killed `Forwarder` and, through its synchronous `GenServer.call`, the collectors.
   **Before slice 02 a DB outage could not stop telemetry collection; after it, it could.**
2. **C2 — persistence failures were still reported as success on the live path.** Slice 04
   added `else` clauses to six *manual* entry points and none to the ingest chain, and
   `Forwarder.normalize_rpc_result/1`'s catch-all wrapped anything unrecognised as
   `{:ok, …}`.
3. **stdio DoS.** `IO.binread(:stdio, :line)` buffers the whole line *before* the
   `@max_line_bytes` check, so the cap was decorative: 50 MB of input cost ~11 GB RSS and
   2 GB OOM-killed the VM with a host-wide kernel OOM event.
4. **Lost test coverage.** `hacktui_sensor_test.exs:18` asserted the old `hub_module`
   default, so it failed *before* its end-to-end assertions — the suite silently stopped
   covering the sensor→hub→TUI path in the slice that rewrote it, while the ratchet
   reported "7 held".
5. **Collector defects:** `consecutive_failures` was never reset, so the network collector
   permanently disabled itself after 5 *cumulative* failures and stayed alive so no
   supervisor could restart it; the 60 s backoff cap was unreachable;
   `Collectors.ProcessSignals` had **no** catch-all `handle_info` (so an unmatched message
   raised rather than being dropped, contradicting slice 03's commit message); and
   `Collectors.Journald` still had the 2 s respawn loop slice 03 claimed to have fixed.
6. **The `Content-Length: 52` doc fix slice 05 claimed and never applied.**

## Out of scope (section 9)

The security reviewer's H2 (masking is cosmetic — `summary` re-leaks what `src` masking
removed) and H3 (`safe_call` returns raw exception text to an unauthenticated caller) are
recorded in `BACKLOG.md` for slice 08, as is the correctness reviewer's H1 (derived
`alert_id` collides across VM restarts) and H2/H3 (the `else` clauses and the repo-present
ingest path have zero test coverage, proven by mutation).
