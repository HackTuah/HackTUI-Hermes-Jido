# Slice 10 — FINDINGS

## F1 — Three failures were one root cause: untyped module injection

`repo` and `query_service` were injected as bare `module()` everywhere. Nothing checked
that a double implemented what the real thing does, so:

```
FunctionClauseError   QueryService.normalize_alert/1      (FakeQueryRepo returned {source, schema})
UndefinedFunctionError FakeTransactionRepo.get_by/2       (never implemented)
UndefinedFunctionError FakeTransactionRepo.get_by/2
```

`Runtime.persist_alert_correlation_metadata/7` has called `repo.get_by/2` since it was
written. The double never had it. That gap survived because nothing could detect it until
the code ran.

Declaring `@behaviour HacktuiStore.RepoBehaviour` on both doubles converts that into a
compile-time warning. This is also the seam an external consumer needs — `use
HacktuiStore, repo: MyApp.Repo` is not expressible until the contract is named.

## F2 — The tests had encoded the doubles' bugs as expected behaviour

`assert [{"alerts", HacktuiStore.Schema.Alert}] = QueryService.alert_queue(FakeQueryRepo)`
asserted a shape **the real repo never produces**. A test that passes only against a
broken stub is worse than no test: it certifies the wrong contract. Same for
`{:update_all, _q, _u, _o}`, which was only observable because the double never executed
the Multi.

The replacements assert the read model and Ecto's real `{rows, nil}` return — and one of
them (`result.persistence.alert_state_guard == 1`) exercises a slice-06 guard that
**no test could reach before**, because the double never ran `Multi.run/3`.

## Gate results

| Gate | Before | After |
|---|---|---|
| test failures | 5 | **2** — baseline lowered |
| credo | 76 | **76** (held) |
| dialyzer | 43 | **43** (held) |
| tests | 171 | **171** |

Across slices 09 and 10 the failure count went **7 → 2**, and 4 of the 5 fixed had
**never passed in any commit**.

## The 2 remaining

Measured across three consecutive full runs to separate the stable failure from the flake:

```
run 1: failures=2  sensor-test-failed=yes
run 2: failures=2  sensor-test-failed=yes
run 3: failures=2  sensor-test-failed=yes
```

- **`HacktuiStore.ReadModelsTest`** — `alert_queue_query/0` selects `entry_type` and
  `payload` from `AuditEvent`, which declares neither. The query **cannot execute**; the
  integration test that runs it has never passed either. Needs a schema decision, not a
  test fix.
- **`HacktuiSensorTest`** — environment-dependent timing. A 100-slot buffer, ~50 network
  observations/sec on a host with live traffic, and a 5-second heartbeat, asserted over a
  2-second poll. It passed once during this slice and failed three consecutive runs after,
  which is why the baseline is 2 rather than 1.
