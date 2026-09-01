# Slice 09 — FINDINGS

## F1 — The subsystem was dead because one module disagreed with three

`Enricher` wrote `Map.put(metadata, "threat_context", description)` — a **string** key
holding a **binary**. Every consumer expected an **atom** key holding a **map**:

```
IngestService     Map.get(metadata, :threat_context, %{})
Runtime           normalize_threat_context/1 accepts only a map
TUI + its test    %{keyword:, severity:}
```

So the threat-score bonus, `maybe_create_threat_alert/2` and the TUI's purple `!` marker
were all unreachable. Three of the four already agreed; the fix was to make the writer
match the readers, not to negotiate a new shape.

Slice 03 made this actively harmful rather than merely dead: supervising the `Indexer`
meant `Enricher` started running, so from that point the malformed value was written into
persisted metadata and consumed by nothing.

## F2 — Two tests had never passed in any commit

`Indexer.table/0`, `Indexer.load/1` and `Enricher.enrich/2` did not exist. Both tests are
now green:

```
$ mix test apps/hacktui_hub/test/threat_intel_test.exs
2 tests, 0 failures
```

**Suite failures 7 → 5** — the first time the baseline has moved down since it was
established.

## F3 — The index was writable by any process in the VM

`:ets.new(@table_name, [:set, :public, :named_table, ...])`. `:public` means any process
could `:ets.insert/2` or `:ets.delete/2` against the detection rule set — and over Erlang
distribution, that includes any cookie-authenticated node. An attacker with a hub
connection could insert false detections or silently delete real ones.

Now `:protected`: any process may read, only the owner may write, and `load/1` goes
through the GenServer. `:ets.safe_fixtable/2` is also wrapped in `try/after` — an
exception inside the fold previously left the table permanently fixed.

## F4 — Threat intel now actually influences a decision

Slice 02 excluded threat-driven promotion *"because that subsystem is dead until slice
06"*. It is alive now, so the exclusion is lifted. Verified end to end through the real
ingest path:

```
threat match, low severity -> ctx=:high  promote?=true
no match,     low severity -> ctx=nil    promote?=false
```

A `mimikatz` indicator on an observation the collector rated **low** now promotes to an
alert. That is the entire point of having threat intel, and until this slice it did
nothing.

**Measurement correction:** an earlier probe of mine reported `promoted=false` for the
matching case and I nearly recorded that as a failure. The probe was wrong, not the code —
with no repo running, `unpersisted_result/2` hardcodes `promoted: false`, so promotion is
never evaluated on that path. The composition above measures the two steps directly.

## Gate results

| Gate | Before | After |
|---|---|---|
| test failures | 7 | **5** — baseline lowered |
| credo | 77 | **76** — baseline lowered |
| dialyzer | 43 | **43** (held) |
| tests | 168 | **171** |

## The 5 remaining failures

None are ThreatIntel. All predate this work:

- 3 × `HacktuiHub.RuntimeTest` — stale test doubles. `FakeTransactionRepo` lacks
  `get_by/2`; `FakeQueryRepo.all/1` returns a raw `{source, schema}` tuple that
  `normalize_alert/1` cannot accept. Fixed by making the fakes `@behaviour`
  implementations, which is the slice-09-era "contracts and behaviours" work.
- 1 × `HacktuiStore.ReadModelsTest` — `alert_queue_query/0` selects `entry_type` and
  `payload` from `AuditEvent`, which declares neither, so the query **cannot execute**.
  Needs a schema decision: add the columns or delete the dead parallel read model.
- 1 × `HacktuiSensorTest` — the environment-dependent timing flake: a 100-slot buffer,
  ~50 network observations/sec, and a 5-second heartbeat, asserted over a 2-second poll.
