# HANDOFF

Rolling state for CLAUDE.md §6. Update at the end of every slice and before any
`/compact`.

**Last updated:** 2026-09-01, end of slice 08.

## Where things stand

Slice 01 (`slice/01-governance-gates`) installed the governance CLAUDE.md assumed
already existed. Before it, four of the seven §4 gates could not run at all and the
section 10 secret scan could never pass.

The gates now run. **Five of them do not pass**, and that is recorded rather than
hidden — see `.claude/gate-baseline.json` and
`docs/slices/01-governance-gates/FINDINGS.md`.

| Gate | State |
|---|---|
| compile `--warnings-as-errors` | pass — hard-blocking |
| format `--check-formatted` | pass — hard-blocking |
| secret scan (corrected pattern) | pass — hard-blocking |
| test | **7 failures** of 168 — ratchet. Six have never passed in any commit; the seventh is a timing flake |
| credo `--strict` | **77 issues** — ratchet |
| dialyzer | **43 warnings** — ratchet (`--format raw`; only `short`/`github` formatters throw) |
| deps.audit | **12 advisories / 5 packages** — advisory, no ratchet |
| hex.audit | **20 advisories / 6 packages** (superset; incl. `hpax` HIGH) — advisory, no ratchet |
| sobelow | 7 findings across 3 apps — advisory |

## How enforcement works

Installed by `mix setup` (which sets `core.hooksPath`) — not by local config alone:
- `.githooks/commit-msg` — rejects any subject without an `NN-kebab-name:` prefix (§7).
- `.githooks/pre-commit` — runs the gates. Hard gates block outright; ratchet gates
  block only on **regression** against `.claude/gate-baseline.json`.

**The ratchet is a deliberate, documented deviation from a literal §4.** Every gate
passing is impossible today, and a literal hook would block the very commits that fix
things — including slice 01's own. Baselines may only decrease; raising one is visible
in the diff and must be rejected in review. There is intentionally no bypass flag, and
section 4 still forbids `--no-verify`, `git -C`, `git stash`, and quiet flags.

## Slices landed

| # | Slice | Commit |
|---|---|---|
| 01 | governance-gates (+ follow-up) | `563b26c`, `193549c` |
| 02 | ingest-unification | `049c57d` |
| 03 | supervision-lifecycle | `f2dceca` |
| 04 | error-propagation | `671049b` |
| 05 | mcp-conformance-and-boundary | `09c42e9` |
| 06 | decision-integrity (+ follow-up) | `3b94fdf`, `25f9764` |
| 07 | mcp-hardening | `2221287` |
| 08 | egress-funnel-and-retractions | this commit |

**Renumbering:** the original plan had 05 = data-integrity and 06 = threat-intel. Review
established the MCP boundary was more urgent, so the order became 05 = MCP conformance,
06 = decision integrity, 07/08 = review remediation. **ThreatIntel is now slice 09** and
is what unblocks the last of the failing tests. Slice-02 and -03 documents that say
"slice 06" for ThreatIntel predate this change.

## Next

**Slice 09 — ThreatIntel.** Its `threat_context` still has incompatible shapes across
four modules, and slice 03 supervising the Indexer made `Enricher` start writing a
string-keyed binary that nothing consumes. Two of the seven failing tests are here.

Then: correlation lost-update race and missing indexes; packaging and Hex metadata;
truthfulness pass over the remaining false doc claims; DARPA artifacts (NOVELTY.md,
evaluation methodology, SBOM, responsible-use).

## Review status

Slices 02–06 were committed unreviewed under an explicit instruction to batch review to
the end. That batch ran with four reviewers on disjoint lenses. **All four returned FAIL.**
Between them they found: an availability regression (a DB outage killed the sensor), a
memory-amplification DoS, persistence failures reported as success on the live path,
silent loss of end-to-end test coverage that the scalar ratchet could not see, and **three
separate "fixed" claims describing changes that were never applied.**

Slices 07 and 08 remediate. The false claims are retracted **in place** in the documents
that made them rather than deleted, because a reader finding the original text is the
failure mode being guarded against.

## Open items not owned by a slice yet

Logged in `BACKLOG.md`: the 13 dependency advisories (incl. a HIGH SQL-injection in
`postgrex`, a *direct* dependency), the sobelow traversal findings, and the compile-time
`@journalctl_path` dead guard that Dialyzer proved.
