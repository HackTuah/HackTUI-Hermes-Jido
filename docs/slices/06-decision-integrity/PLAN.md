# Slice 06 — decision-integrity

**Branch:** `slice/06-decision-integrity`
**Status:** in progress
**Depends on:** slice 05 (`09c42e9`)

## Why

A SOC platform exists to retain analyst decisions. This one loses them three ways.

**1. `disposition` never reaches any reader.** `normalize_alert/1` in `query_service.ex`
omits it from both clauses. It is a `validate_required` column
(`schema/alert.ex:22`), written on persist (`alerts.ex:55`) and read for aggregate
rehydration (`runtime.ex`), but absent from the TUI, the MCP tools and the dashboard. An
analyst marks something `false_positive` and every reader renders it as untriaged.

**2. The lifecycle normalizers don't match the domain.** `AlertLifecycle` defines six
states and six dispositions. `normalize_alert_state/1` handles three
(`open`, `investigating`, `closed`) and maps everything else to `:open` — so
`:acknowledged`, `:suppressed` and `:resolved` silently become `:open`, and a resolved
alert re-materialises as open on every read. `normalize_disposition/1` handles
`unknown | benign | malicious` — and **`benign` and `malicious` are not canonical values
at all**, while `benign_true_activity`, which `DemoSeed` actually writes, falls through
to `:unknown`.

**3. Approval and transition writes have no state guard.** `Actions.approval_multi/2`
and `Alerts.transition_multi/2` build `update_all` keyed only on the record id, and
`update_all`'s `{count, nil}` return is never checked. Sequential double approval *is*
currently blocked — `action_request.ex:86` returns `{:error, :already_decided}` and the
read model filters to pending — so this is a **TOCTOU race**, not a currently-possible
double approval: two concurrent approvers both pass the aggregate guard, both writes
succeed, and the second silently overwrites `approved_by`/`approved_at`.

No changeset declares a `unique_constraint`, so a concurrent duplicate raises
`Ecto.ConstraintError` out of `Multi.insert` instead of returning a changeset error.

## In scope

1. Return `disposition` from both `normalize_alert/1` clauses.
2. Derive both normalizers from `AlertLifecycle.states/0` and `dispositions/0` at compile
   time, so the domain is the single source of truth. (An unrecognised value still coerces
   to `:open`/`:unknown`; an earlier draft of this plan wrongly called that an explicit
   fallback.)
3. Add `where` guards on the approval and transition `update_all` calls, and assert the
   affected-row count so a no-op write is an error rather than a success.
4. Add `unique_constraint/2` to the changesets whose migrations already declare unique
   indexes.
5. Round-trip tests over every state and disposition.

## Out of scope (section 9)

The correlation lost-update race (`runtime.ex` read-modify-write on `hit_count` /
`observation_refs`), missing indexes, unbounded operator queries, and audit-table
tamper-evidence — all slice 07. ThreatIntel shape unification — slice 08.

## Acceptance criteria

- [ ] Every canonical state and disposition round-trips unchanged.
- [ ] `disposition` is present in `alert_queue/1` output.
- [ ] A second approval of an already-approved action fails rather than overwriting.
- [ ] A transition from a stale state fails rather than winning.
- [ ] No ratchet regression: test ≤ 7, credo ≤ 77, dialyzer ≤ 43.
