# Slice 06 — FINDINGS

## F1 — `disposition` never reached any reader

`normalize_alert/1` omitted it from **both** clauses (`query_service.ex:352` struct form,
`:370` map form). It is a `validate_required` column, written on persist and read for
aggregate rehydration, but absent from the TUI, the MCP tools and the dashboard. An
analyst marked something `false_positive` and every reader rendered it as untriaged.

Now returned from both clauses, and pinned by a test.

## F2 — The lifecycle normalisers did not match the domain

`AlertLifecycle` defines six states and six dispositions. `Runtime.normalize_alert_state/1`
handled three:

```elixir
"open" -> :open; "investigating" -> :investigating; "closed" -> :closed; _ -> :open
```

so `:acknowledged`, `:suppressed` and `:resolved` silently became `:open` — a resolved
alert re-materialised as open on every read.

`normalize_disposition/1` was worse: it accepted `"benign"` and `"malicious"`, which are
**not canonical dispositions at all**, while `benign_true_activity` — what `DemoSeed`
actually writes — fell through to `:unknown`.

Both now derive from `AlertLifecycle.states/0` and `dispositions/0`, so the domain is the
single source of truth. Verified:

```
states:        open, acknowledged, investigating, suppressed, resolved, closed  -> all ok
dispositions:  unknown, true_positive, benign_true_activity, false_positive,
               duplicate, expected_recurring_activity                            -> all ok
```

A test asserts `:benign` and `:malicious` are not in the canonical set, so the old
non-canonical values cannot creep back.

**Note on scope:** `QueryService.normalize_state/1` is a *different* function that returns
lowercased strings for the read model. It is lossless and was not the defect; an initial
test of mine wrongly assumed it returned atoms. The loss was on the aggregate path.

## F3 — Approval and transition writes had no state guard

`Actions.approval_multi/2` and `Alerts.transition_multi/2` built `update_all` keyed only
on the record id, and `update_all`'s `{count, nil}` return was never checked.

Sequential double approval was already blocked — `action_request.ex:86` returns
`{:error, :already_decided}` and the read model filters to pending — so this was a
**TOCTOU race**, not a currently-possible double approval, and an earlier summary
overstated it. Two concurrent approvers both pass the aggregate guard, both writes
succeed, and the second silently overwrites `approved_by`/`approved_at`.

**Correction (batched review):** the PLAN and an earlier version of this document said
the change made an unrecognised value "an explicit fallback rather than a silent coercion
to `:open`". That was false — `Enum.find/3`'s default *is* `:open`, so it is still a
coercion; only the set of inputs that coerce shrank. A test now asserts the real
behaviour rather than the claim.

Both now carry a state guard in the `where` (`approval_status == "pending_approval"`,
`record.state == ^from_state`) plus a `Multi.run` that fails on a zero-row update:
`{:error, :already_decided}` and `{:error, {:stale_transition, from_state}}`.

## F4 — No changeset declared a `unique_constraint`

All four migrations create unique indexes; no changeset declared the matching constraint,
so a concurrent duplicate raised `Ecto.ConstraintError` out of `Multi.insert` rather than
returning a changeset error a caller could handle. Added and verified:

```
Alert: [:alert_id]   CaseRecord: [:case_id]
ActionRequest: [:action_request_id]   AuditEvent: [:audit_id]
```

## Gate results

| Gate | Before | After |
|---|---|---|
| test failures | 7 | **7** (held; 152 → 159 tests) |
| credo | 77 | **77** (held) |
| dialyzer | 43 | **43** (held) |

## F5 — Batched review found a regression this slice introduced

`Runtime.approve_action/3` was the **one** public function of seven that slice 04 missed
when adding `else -> normalize_persistence_error(other)`. That was latent until slice 06's
`Multi.run` guard made `{:error, :action_request_guard, :already_decided, changes}`
reachable, at which point the bare `with` propagated the raw 4-tuple — and
`demo/runner.ex:62` hard-matches `{:ok, result}`, so a duplicate approval raised
`MatchError`. Slice 06 was a net regression for that caller until this follow-up.

```
$ for fn in create_alert transition_alert open_case transition_case \
            request_action approve_action record_audit; do ... done
  approve_action     else clause: *** NO ***      (all six others: yes)
```

Fixed. All seven now normalise.

## F6 — The guards had zero executing coverage

`FakeRepo.transaction/1` was `{:ok, Map.new(Ecto.Multi.to_list(multi))}` — it converted
the Multi to a list and never ran it, so `Multi.run/3` was never invoked. This document
previously claimed the guards were "unit-tested against stubs". **They were shape-tested
only.** `FakeRepo` now executes the Multi and records the raw operations, and
`state_guard_test.exs` exercises both the matching and zero-row paths for alerts and
actions.

## F7 — `"investigating"` is not a case status

`runtime.ex` filtered `case_record.status in ["open", "triage", "investigating"]`.
`CaseLifecycle.states/0` has no `:investigating` — the value is `:active_investigation`.
`find_existing_case_for_alert/2` therefore never matched a case under active
investigation, response-pending-approval, response-in-progress or monitoring, so a second
high-severity alert opened a **duplicate case** for one already under response. Corrected.

`Cases.transition_multi/2` was also left unguarded while alerts and actions were fixed —
an undocumented asymmetry. Now guarded on `from_status`.

## Not verified

**RETRACTED (slice 08):** when this slice shipped, the guards had **zero** executing
coverage -- `FakeRepo.transaction/1` converted the Multi to a list and never ran it, so
`Multi.run/3` was never invoked. The claim "unit-tested against stubs" was false. The
follow-up commit gave `FakeRepo` a real interpreter; the guards are exercised now. **They have still
not been run against a live PostgreSQL**, and no true concurrency test exists — that needs
the `:integration` path, which has never run. Recorded in `BACKLOG.md`.
