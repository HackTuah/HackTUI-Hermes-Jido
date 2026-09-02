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

## Known-failing tests carried at baseline

Two failures are recorded in `.claude/gate-baseline.json` as `test_failures: 2`. Both
predate the current work and reproduce on clean `main` across three consecutive isolated
worktree runs. **Neither is permitted to be carried silently.**

### `HacktuiStore.ReadModelsTest` — "builds alert queue query"

**Root cause, confirmed.** `ReadModels.alert_queue_query/0` selects `event.entry_type` and
`event.payload`; `HacktuiStore.Schema.AuditEvent` declares neither, and neither column
exists in any migration. Ecto validates fields at *planning* time, so the function returns
a `%Ecto.Query{}` and raises only on execution. The query **cannot execute against any
database**.

There are also two competing definitions of the alert queue — this one and
`QueryService.alert_queue/1`, which is the one the live path uses.

**Disposition:** the duplicate definition is the defect. Scheduled for the read-model work;
the fix is expected to be deletion, not repair.

### `HacktuiSensorTest` — "starts collector supervision boundaries and ingests live observations locally"

**Root cause, confirmed.** A timing race, not a defect in the code under test.
`Collectors.ProcessSignals` schedules its first collection at boot; the test's first
statement clears recent observations, erasing it. The next collection is at
`process_signals_interval_ms` (5000 ms) while the test's `assert_eventually` budgets
20 × 100 ms = 2000 ms. It passes only when two unordered casts from different processes
happen to land in the lucky order.

**Disposition:** fix is to set `process_signals_interval_ms: 50` in `config/test.exs`, or
to `send(collector_pid, :collect)` and assert on the result. Scheduled with the sensor
work. Until then the flake is recorded here rather than re-diagnosed each time it appears.

---

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
