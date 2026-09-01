# Slice 07 — FINDINGS

Two batched reviewers (security, correctness/OTP) both returned **FAIL** on slices 02–06.
Everything here was reproduced before being accepted.

## F1 — A database outage killed the sensor (introduced by slice 02)

`repo_available?/1` tested `not is_nil(Process.whereis(repo))`. An `Ecto.Repo` supervisor
is registered under its module name whether or not the database is reachable, so the guard
passed and `repo.transaction/1` raised. No rescue existed anywhere in the chain, so the
raise killed `Forwarder`, and `ProcessSignals`' synchronous `GenServer.call` killed the
collector too.

**Before slice 02 the sensor never touched the database, so a DB outage could not stop
telemetry collection. After it, losing the database also lost the sensor.**

Verified before and after, with the repo pointed at a dead port:
```
before: {:RAISED, DBConnection.ConnectionError}
after:  RETURNED ok, persistence={:persistence_unavailable, DBConnection.ConnectionError}
```

## F2 — Persistence failures were still reported as success on the live path

Slice 04's commit message claimed the leak was closed. It added `else` clauses to six
*manual* entry points — `create_alert`, `transition_alert`, `open_case`,
`transition_case`, `request_action`, `record_audit` — and **none to the ingest chain**,
which is the path slice 02 had just made live. `Forwarder.normalize_rpc_result/1`'s
catch-all `{:ok, other}` then converted the leaked `Ecto.Multi` 4-tuple into a success and
incremented the `accepted` counter.

Fixed at both ends: the ingest chain normalises, and the Forwarder's catch-all now returns
`{:error, {:unexpected_hub_result, other}}`.

## F3 — The stdio frame cap was decorative; unauthenticated local DoS

`IO.binread(:stdio, :line)` returns the entire line, so `byte_size(line) > @max_line_bytes`
was checked only *after* the bytes were allocated. The reviewer measured 50 MB of input
costing ~11 GB RSS, and 2 GB OOM-killing the VM with a **host-wide** kernel OOM event
attributed to an unrelated process.

Reads are now bounded as they happen. Measured after the fix: 20 MB of unterminated input
peaks at **464 MB** rather than growing without limit.

## F4 — The suite silently lost end-to-end coverage, and the ratchet could not see it

`hacktui_sensor_test.exs:18` asserted `hub_module: HacktuiHub.IngestService`. Slice 02
changed that default to `HacktuiHub.Runtime` and did not update the test, so it failed at
line 18 — *before* the assertions at line 21 that check a live observation reaching
`live_dashboard_snapshot().observations`.

The failure **count** never moved, so "test 7 held" reported success across four
subsequent slices while the sensor→hub→TUI path had no coverage at all. This is the
clearest demonstration yet that a scalar ratchet cannot see coverage loss. Fixed; the test
now fails at line 21 (the pre-existing timing flake) with the end-to-end assertions
executing again.

## F5 — Collector defects

- `consecutive_failures` was never reset on a successful capture start, so the counter
  accumulated over the process lifetime. A collector working normally but whose `tshark`
  restarted 6 times over hours would permanently disable itself — and because it returns
  `{:noreply, …}` rather than stopping, **no supervisor restart could recover it**.
- The `@max_restart_delay_ms 60_000` cap was unreachable: with `@max_restart_attempts 5`
  the largest delay was `2_000 * 2^4 = 32s`. Attempts raised to 8 so the documented cap
  is real.
- `Collectors.ProcessSignals` had **no** catch-all `handle_info`, so an unmatched message
  raised `FunctionClauseError` and killed the collector. Slice 03's commit message claimed
  "all three collectors" log unmatched messages; two of three did.
- `Collectors.Journald` still rescheduled every 2 s forever — the identical defect slice 03
  fixed in `Collectors.Network` and claimed to have fixed generally.

## F6 — A doc fix claimed in slice 05 was never applied

`docs/mcp_stdio_quickstart.md:25` still declared `Content-Length: 52` for a 58-byte body.
Slice 05's PLAN and FINDINGS both listed this as corrected. Running it produced two parse
errors and no initialize response. **This is the third instance of the claimed-but-unapplied
pattern in this project's history.** Now corrected to newline framing, and verified by
running the command the doc prints.

## Gate results

| Gate | Before | After |
|---|---|---|
| test failures | 7 | **7** (held; 168 tests) |
| credo | 77 | **77** (held) |
| dialyzer | 43 | **43** (held) |

Three regressions were caught by the ratchet during this slice: two `with` blocks reduced
to a single clause plus `else` (credo), and two branches that the C1 rescue made provably
unreachable (dialyzer). All removed rather than suppressed.

## Deliberately not fixed — recorded in BACKLOG.md

- **Masking is cosmetic.** `MCP.Egress` masks `src`/`dst` but `summary` concatenates the
  same values and is not in `@masked_fields`, so the private IP removed from `src`
  egresses verbatim in the same record. Net privacy benefit for network flows is ~zero.
- **`safe_call` leaks internals** — stacktraces, SQL, table names, dependency versions and
  absolute paths reach an unauthenticated caller, and because the MCP task removes the
  logger, the caller is the *only* party informed.
- **Derived `alert_id` collides across VM restarts** — collectors number observations from
  a per-VM monotonic counter, so the Nth high-severity observation after a restart reuses
  an id, now colliding with slice 06's `unique_constraint`.
- **Slice 04's `else` clauses and slice 02's repo-present path have zero test coverage** —
  proven by mutation: reintroducing the original defect leaves the suite green.
