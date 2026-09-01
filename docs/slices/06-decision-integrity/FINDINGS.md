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
single source of truth and an unrecognised value is an explicit fallback. Verified:

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

## Not verified

The guards are asserted by construction and by unit tests against stub repos. **They have
not been exercised against a live PostgreSQL**, and no concurrent-approval test exists —
that needs the `:integration` path, which has never run. Recorded in `BACKLOG.md`.
