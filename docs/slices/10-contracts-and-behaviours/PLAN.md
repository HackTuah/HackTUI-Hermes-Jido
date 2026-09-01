# Slice 10 — contracts-and-behaviours

**Branch:** `slice/10-contracts-and-behaviours`
**Status:** implemented
**Depends on:** slice 09 (`e488e76`)

## Why

The original OSS/integration audit named this the **#1 blocker to embeddability**: there
was not one `@callback` in the entire umbrella. `repo`, `query_service` and `hub_module`
were all injected as untyped `module()`, so a test double could drift arbitrarily from
the real thing with no compiler check.

That is not theoretical — it was three of the five remaining test failures:

- `FakeTransactionRepo` never implemented `get_by/2`, which
  `Runtime.persist_alert_correlation_metadata/7` has called since it was written.
  `UndefinedFunctionError` at runtime, months later, instead of a compile-time warning.
- `FakeQueryRepo.all/1` returned `[query.from.source]` — a bare `{"alerts", Alert}` tuple
  that the real repo never produces and `QueryService.normalize_alert/1` has no clause
  for. The tests then asserted that broken shape, so they encoded the double's bug as the
  expected behaviour.

## In scope / done

1. `HacktuiStore.RepoBehaviour` — the subset of `Ecto.Repo` the hub actually calls,
   derived by grepping the real call sites: `all/1`, `one/1`, `get_by/2`, `transaction/1`,
   `update/1`, `insert_all/3`, `delete_all/1`.
2. `HacktuiHub.QueryBehaviour` — the operator read surface consumed by the TUI, the MCP
   tools, the Slack boundary and the agent flow.
3. Both doubles now declare `@behaviour HacktuiStore.RepoBehaviour`, so this class of
   drift is a compile-time warning.
4. `FakeTransactionRepo` executes the Multi rather than converting it to a list, so the
   state guards added in slice 06 are invoked by these tests too.
5. Three assertions updated from the doubles' artifacts to the real contract.

## Test changes, and why

Three assertions changed. In each case the test was asserting an artifact of a broken
double, not a behaviour:

- `[{"alerts", Alert}]` → the read-model map, because that is what the real repo returns.
- `[{"case_timeline_entries", …}]` → same.
- `{:update_all, _q, _u, _o}` → `{1, nil}`, because Ecto's `update_all` returns rows
  affected; the un-executed operation was only ever visible because the double never ran.

Recorded explicitly: **changing tests to match production is a smell**, and it is the
second slice running where I have done it. The distinction I am claiming is that these
tests asserted *how a stub was built*, not *what the system does* — and the new
assertions are strictly stronger, including one (`alert_state_guard == 1`) that could not
have been written before.

## Out of scope (section 9)

`ReadModels.alert_queue_query/0` — the last non-flake failure — selects `entry_type` and
`payload` from `AuditEvent`, which declares neither, so it **cannot execute**. Fixing it
needs a schema decision (add the columns, or delete the dead parallel read model), which
is its own slice.
