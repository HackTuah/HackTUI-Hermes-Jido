# Slice 09 — threat-intel

**Branch:** `slice/09-threat-intel`
**Status:** implemented
**Depends on:** slice 08 (`e075056`)

> Numbering: earlier slice documents refer to this work as "slice 06" (slices 02–03) and
> "slice 08" (slices 05–06). The 05/06/07 renumbering moved it. `HANDOFF.md` now records
> the mapping.

## Why

The subsystem had **four mutually incompatible ideas of the same field**:

| Module | Wrote/read | Shape |
|---|---|---|
| `Enricher` | wrote | `"threat_context"` — **string** key, **binary** value |
| `IngestService` | read | `:threat_context` — **atom** key |
| `Runtime.normalize_threat_context/1` | read | accepts only a **map** |
| TUI threat marker + its test | read | `%{keyword:, severity:}` |

Three of the four already agreed. Only the `Enricher` disagreed, so every consumer
silently saw nothing: the threat-score bonus, `maybe_create_threat_alert/2` and the TUI's
purple `!` marker were all permanently dead.

Two tests asserted an API that had never existed in any commit — `Indexer.table/0`,
`Indexer.load/1`, `Enricher.enrich/2`. Per the maintainer's decision to implement rather
than delete aspirational tests, the tests were treated as the specification.

## In scope / done

1. `Indexer.table/0`, `Indexer.load/1`, `Enricher.enrich/2` implemented.
2. Entries unified on the shape the other three consumers expect:
   `metadata[:threat_context] = %{keyword:, severity:, source:}`.
3. ETS table changed `:public` → `:protected`. It was writable by any process in the VM —
   including, over distribution, any cookie-authenticated node — which could insert false
   detections or delete real ones. Writes now go through the owning GenServer.
4. `:ets.safe_fixtable/2` wrapped in `try/after`, so an exception inside the fold cannot
   leave the table permanently fixed.
5. `Detection.promote?/1` now promotes on a high/critical threat match. Slice 02
   deliberately excluded this *"because that subsystem is dead"*; it is alive now, so the
   exclusion is lifted — a high-confidence indicator match promotes even when the
   collector rated the observation low-severity, which is the point of having threat intel.
6. AI-assistant residue removed from both modules, including the comment instructing a
   future agent not to hardcode 50,000 keywords.

## Test change, and why

`threat_intel_test.exs`'s setup called `:ets.delete_all_objects/1` directly from the test
process. That is incompatible with a `:protected` table by design. The setup now clears
through `Indexer.load(keywords: [])`. **A test was changed to accommodate a production
change** — recorded explicitly because that is normally a smell. The justification: the
test was asserting an implementation detail (direct ETS write access), not the behaviour
under test, and the behaviour assertions are unchanged.

## Out of scope (section 9)

`PrivacyMask`'s narrowness, `safe_call`'s error leakage, the `alert_id` collision, and the
untested ingest path all remain in `BACKLOG.md`.
