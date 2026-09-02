# Residuals

Known-and-accepted gaps, with the evidence that made them acceptable. A residual is not a
TODO: it is a finding that was investigated, understood, and deliberately not closed, with
the reasoning recorded so a reviewer can disagree with the judgement rather than guess at it.

Anything here that turns out to be wrong should be promoted to a defect and fixed. Anything
carried without a root cause or a tracked issue should be treated as a process failure, not
a residual.

---

## Equivalent mutants

Two mutants in `tools/mutants/c5.tsv`'s domain survive and are *supposed to*. Both were
probed rather than assumed — "the mutant survives because the code is equivalent" is itself
a claim that needs testing.

### `take_cells/3`'s over-budget guard

Removing the guard leaves the suite green. Not a coverage gap: `render_panel` re-clips
every line through `truncate_rendered/2` (`live_dashboard_view.ex`), whose own guard
catches the overflow, so `take_cells`'s guard is belt-and-braces behind a working one.

Verified by reading the full path, not inferred: every panel line passes through
`truncate_rendered(line, inner_width)` before it is padded and framed.

**Kept anyway.** It is cheap, and it is the guard that holds if `render_panel` is ever
restructured to clip elsewhere.

### `cell_width/1`'s Hangul Jamo clause (U+1100–U+115F)

Changing the clause to return `1` instead of `2` leaves the suite green, and **no test can
distinguish the two**. Hangul Jamo are conjoining: a run of them collapses to a single
grapheme cluster. Probed directly —

    payload = String.duplicate(<<0x1100::utf8>>, 50)
    __clip_rendered__(payload, 20) |> String.length()
    #=> 1        both with the clause and with it mutated

so neither width nor truncation is measurable through this range. Over-counting is the safe
direction (it truncates early rather than overflowing a row), so the clause stays and the
codepoint is deliberately **absent** from the width test's list, with this reasoning cited
there rather than left looking covered.

---

## Performance budget

**Sanitiser cost: ~13 µs per 15-field tshark line. This is a budget, not a target.**

Three independent measurements were taken. Two reviewers measured **13.3 µs** and
**19.2 µs**; the implementer measured **4.46 µs**. The two independent figures agree with
each other and not with the implementer's, so **the implementer's is treated as the
outlier** and the higher figure is the one recorded.

Settled across all three measurements: an 8 MB single line costs **sub-millisecond**
(0.27 / 0.32 / 0.62 ms). An earlier implementer figure of 33.9 ms for that case was wrong
by two orders of magnitude and is retracted.

Regressions against this budget should be measured by whoever claims them, and a
disagreement between two measurements is a finding, not a rounding error.

---

## Known-failing tests: RESOLVED in slice 13

Both failures recorded here are fixed. The suite is **248 tests, 0 failures** across three
consecutive runs, and `.claude/gate-baseline.json` `test_failures` is **0**. Kept in this
ledger because the reasoning is the point, not the outcome.

### `HacktuiSensorTest` - resolved

**Root cause.** A production cadence colliding with a test budget, not a defect in the code
under test. `Collectors.ProcessSignals` schedules its first collection at boot; the test's
first statement clears recent observations, erasing it; the next collection is at
`@default_process_interval_ms` (5000 ms) while `assert_eventually` budgets 20 x 100 ms
(2000 ms). It passed only when two unordered casts from different processes happened to land
in the lucky order.

**Fix.** `config :hacktui_sensor, HacktuiSensor, process_signals_interval_ms: 50` in
`config/test.exs`. The 2000 ms budget was the intent; 5000 ms is a production number that
does not belong in a test run.

### `HacktuiStore.ReadModelsTest` - resolved by deletion, and this distinction matters

**This was a duplicate-definition defect, not a query bug.** `alert_queue_query/0` was a
**second** definition of the alert queue, alongside the live one at
`HacktuiHub.QueryService.alert_queue/1`. It selected `entry_type` and `payload`, which
`HacktuiStore.Schema.AuditEvent` does not declare and no migration creates, so it could
never execute against a database - and it had **no production caller**. Ecto validates
fields at planning time, so it returned a `%Ecto.Query{}` and would have raised only on
`Repo.all`; its test asserted `query.from.source`, which never plans.

**Fix: removed the duplication rather than repairing dead code.** Repairing it would have
left a second, unused definition of an operator read model free to drift from the real one.

That is the difference between "we deleted a failing test" and "we removed a drift risk,"
and it is why the guard below exists rather than the fix ending at deletion.

**Guard, so it cannot return.** `apps/hacktui_hub/test/query_boundary_test.exs` asserts that
`alert_queue`, `case_board`, `approval_inbox` and `audit_events` each have exactly one
public definition, in `query_service.ex`. Verified to fire: reintroducing a duplicate
`alert_queue_query/0` fails two named tests.

## Not residuals: tracked blocking defects

A blocking-class finding cannot be recorded as a residual. This section names them and the
slice that closes each.

**Aging rule.** No entry here may be older than one slice without an assigned slice number
and a named owner. A signoff that leaves an unassigned entry fails review. Without that
rule this section becomes the second place blocking items go quiet, which is the thing it
was created to prevent.

*Currently open: none.*

### CLOSED — signoff gate accepted an empty diff (slice 13b)

`.githooks/pre-commit` hashed the staged diff and looked for that value in a
`REVIEW.signoff`. With nothing staged the hash is the sha256 of the empty string, and a
signoff containing it was reported as "matches staged diff." Blocking class 1: a verdict
without a probe.

Closed by `tools/gate.sh attestation`, which **derives** each commit's diff hash from the
pushed range and compares it to the claim in that commit's message, per commit. An empty
reviewable diff is a distinct verdict and can never be a match; `commit-msg` refuses to
create one.

Demonstrated: CI run 33589821607 reddened attestation and only attestation when an
already-pushed commit was amended without updating its trailer
(claimed `50101f8c...`, derived `b9e61f7a...`).

**What it does not close:** the attested party still produces the record. A signature
against a tracked `allowed-signers` file is what makes the attester a different privilege
domain, and that remains unbuilt.

## Unverified by construction

- **`raw_message` has no test coverage on the network collector path.** It is a field on
  `AcceptObservation` but not on `ObservationAccepted`, so it cannot be read back through
  `IngestService` for that collector. Coverage requires a different observation point.

## Deferred to named work

- `replay/runner.ex` and `demo_terminal_view.ex` remain unsanitised terminal sinks.
- `HacktuiCore.Text.for_model/1` has no production caller; the module's four-sink claim is
  one and a half sinks wired.
- Ingest stringifies metadata booleans (`"injection_attempt?" => "true"`), so a consumer
  pattern-matching on `true` would miss.
- `Text.ingest/2` splits emoji ZWJ sequences (👨‍👩‍👧 becomes three glyphs). Width stays within
  budget; displayed identity changes.
- The terminal defense is **filtering, not structure**. A cell-buffer renderer, which makes
  escapes unrepresentable rather than removed, is the stronger design and is not built.
