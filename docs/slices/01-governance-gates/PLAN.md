# Slice 01 — governance-gates

**Branch:** `slice/01-governance-gates`
**Status:** landed on main as `563b26c`; follow-up commit applies round-4 review fixes
**Depends on:** nothing (bootstrap slice)

> CLAUDE.md numbers its sections 0–10. An earlier draft of this file cited *line numbers*
> as section numbers (§44, §85, §38–41). Those citations are corrected here; the defect
> was reported by review as an instance of the imprecise citation section 5 forbids.

## Why

`CLAUDE.md` defines a seven-gate commit check (section 4) and a numbered-slice workflow
(sections 2 and 6), and stated the gates were "enforced by a PreToolUse hook
(`.claude/settings.json`)". None of that infrastructure existed:

| Required by CLAUDE.md | Reality at `f0494af` |
|---|---|
| The enforcement hook named in section 4 | No `.claude/` directory; no git hooks either |
| `docs/slices/NN-kebab-name/` (section 6) | Did not exist |
| `FINDINGS.md`, `HANDOFF.md` (section 6) | Absent |
| `mix credo --strict` (section 4) | `credo` not a dependency |
| `mix dialyzer` (section 4) | `dialyxir` not a dependency |
| `mix deps.audit` (section 4) | `mix_audit` not a dependency |
| `mix sobelow --exit` (section 4) | `sobelow` not a dependency |

Root `mix.exs:11` was literally `deps: []`. **Four of the seven gates could not run**, so
every claim that a change "passed the gates" was unfalsifiable.

## In scope

1. Add `credo`, `dialyxir`, `mix_audit`, `sobelow`; add `.credo.exs`,
   `.dialyzer_ignore.exs`, PLT path under `priv/plts` (gitignored).
2. Enforcement via **`.githooks/` + `core.hooksPath`**, installed by `mix setup`.
   *(Changed from `.claude/settings.json`: a Claude-side PreToolUse hook only covers this
   agent's tool calls, not commits made by a human in a terminal or by CI. CLAUDE.md
   section 4 has been amended to name the real mechanism and to state plainly that
   `--no-verify` bypasses any hook — enforcement here is policy, not a technical control.)*
3. `docs/slices/` templates + root `HANDOFF.md`.
4. Fix CLAUDE.md section 10's secret-scan pattern, which could never pass.
5. Commit `CLAUDE.md` (was untracked).
6. `.tool-versions`, an `elixir:` requirement in root `mix.exs`, and `.env.example`.
7. Drop three orphaned `mix.lock` entries.
8. `.github/workflows/ci.yml` with a `postgres:16` service.
9. Record a gate baseline in `FINDINGS.md` from real output.

## Out of scope (section 9)

No production code changes — verified: `git diff --name-only f0494af..HEAD -- apps/ config/ bin/`
is empty. The 7 failing tests, the MCP transport crash, and the ingest gap are slices 02–06.
Discoveries are logged to `BACKLOG.md`, not fixed.

## The bootstrap conflict — and how this slice resolves it

**CLAUDE.md section 4 cannot be satisfied literally**, and following it literally would
prevent all remedial work: a hook blocking every commit until all seven gates pass would
block the commits that fix the failures, including this one.

**Resolution — a ratchet that fails closed:**

- **Hard-blocking:** `mix compile --warnings-as-errors`, `mix format --check-formatted`,
  the corrected secret scan, the section 7 slice-reference check, a clean working tree,
  and a `REVIEW.signoff` matching the staged diff.
- **Regression-blocking:** `mix test`, `mix credo --strict`, `mix dialyzer` — compared
  against `.claude/gate-baseline.json`. Baselines may only decrease.
- **Advisory:** `mix deps.audit`, `mix hex.audit`, `mix sobelow`.

**Fail-closed is the load-bearing property.** Round-1 review proved the first
implementation scored a *crashed* gate as an improvement (no summary line → count 0 →
0 > 7 false → pass, printing "improved"). Each ratchet now requires its gate to emit a
recognisable summary; absence is a hard failure, never a pass. A missing or unparsable
baseline is likewise a hard failure, not a skip.

## Acceptance criteria

- [x] All four gate tools installed; each runs and produces output.
- [x] Hook blocks a commit that breaks a hard gate — **verified by attempting one**;
      transcript recorded in FINDINGS F11.
- [x] Hook blocks a commit message with no `NN-` slice reference, and the `Merge `
      bypass found in review is closed (FINDINGS F10).
- [x] Hook permits this slice's own commit — `563b26c` passed its own gate with a
      matching `REVIEW.signoff`.
- [x] `mix deps.get` leaves `mix.lock` unmodified.
- [x] CLAUDE.md section 10's pattern returns empty.
- [x] `FINDINGS.md` records baseline output for all seven gates, with commands, and the
      counts reproduce from the methods stated in `.claude/gate-baseline.json._method`.
- [x] CI workflow present with the Postgres service **and a baseline comparison** so it
      is not green-always.
- [x] Ratchets fail closed on gate crash and on missing baseline (FINDINGS F9).
- [x] Hooks installable by construction (`mix setup`). **Round-4 review found this was
      false as shipped** — `mix do ... git config` cannot work, since `mix do` runs Mix
      tasks and there is no `git` task. Restored to `mix cmd --app`; `mix setup` now
      exits 0 and sets `core.hooksPath`.
- [ ] Independent reviewer sign-off (sections 0 and 8). Rounds 1, 2 and 3 all returned
      **FAIL**; round 3 was a fresh reviewer with no prior context, per the maintainer's
      definition of independent review. Its blockers are fixed; residual items are in
      BACKLOG.md. I do not self-certify.

## Verification

```bash
mix setup                                  # installs hooks via core.hooksPath
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict                         # baseline 77
mix dialyzer --format raw | grep 'Total errors'   # baseline 61
mix do deps.loadpaths + deps.audit         # 13 advisories, 6 packages
git ls-files | grep -Ei '(^|/)\.env$|\.(key|pem|pcap|pcapng|p12)$'   # expect empty
git status --porcelain mix.lock            # expect empty
```
