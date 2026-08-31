# HANDOFF

Rolling state for CLAUDE.md §6. Update at the end of every slice and before any
`/compact`.

**Last updated:** 2026-08-31, end of slice 01.

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
| test | **7 failures** — ratchet, slice 06 drives to 0 |
| credo `--strict` | **77 issues** — ratchet |
| dialyzer | **61 warnings** — ratchet (`--format raw`; only `short`/`github` formatters throw) |
| deps.audit | **13 advisories / 6 packages** — advisory, no ratchet |
| hex.audit | **23 advisories / 7 packages** (superset; incl. `hpax` HIGH) — advisory, no ratchet |
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

## Next

Slice 02 — `02-ingest-unification`. The keystone: `Runtime.accept_observation/2` has
zero production callers, so live telemetry is never persisted and the audit trail
claimed throughout the docs does not exist for live operation. Nothing downstream
(correlation, dedup, threat scoring, auto-case creation) is reachable until this lands.

Ordering after that: 03 supervision → 04 error propagation (includes the MCP transport
crash) → 05 data integrity → 06 threat-intel + green suite → 07/08 security → 09–12
integration, packaging, truthfulness, DARPA artifacts.

## Open items not owned by a slice yet

Logged in `BACKLOG.md`: the 13 dependency advisories (incl. a HIGH SQL-injection in
`postgrex`, a *direct* dependency), the sobelow traversal findings, and the compile-time
`@journalctl_path` dead guard that Dialyzer proved.
