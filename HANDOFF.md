# HANDOFF

State for a session starting with no memory of the previous one. Everything here was
re-verified by command at write time; where a number came from a command, the command is
named so you can re-run it rather than trust it.

**Written:** 2026-09-02, after slice 13b. **Governing rules:** `CLAUDE.md` (gitignored, at
repo root). **Slice records:** `internal/slices/NN-*/` (gitignored, local only).
**Published residuals:** `docs/residuals.md`.

---

## 1. Where things stand

`main` is at `bbc4372`. The suite is **248 tests, 0 failures** — green for the first time.

| Gate | Baseline | State |
|---|---|---|
| compile `--warnings-as-errors` | — | pass, hard-blocking |
| format `--check-formatted` | — | pass, hard-blocking |
| tracked secret-shaped files | — | pass, hard-blocking |
| test | **0** | pass |
| credo `--strict` | **76** | held |
| dialyzer | **43** | held |
| deps.audit / hex.audit | 12 / 20 | advisory, not blocking (slice 16's work) |
| mutation (`tools/mutate.sh`) | 0 survivors | 14/14 killed, CANARY aborts |
| attestation | — | **RED on `main` — see §2** |

Slices 01 through 13b are merged. Slice 14 has a PLAN and CRITERIA and **no code**.

## 2. The one red gate, and why it is not a bug

`Gate - attestation` fails on `bbc4372` (run **33592712829**).

`tools/gate.sh attestation` re-derives each commit's diff hash and compares it to the
`Reviewed-diff` trailer in that commit's message. `bbc4372` was created by **squash**-merging
PR #2: its diff is the *union* of the branch's commits, but its message inherited a trailer
from one of them.

    claimed (inherited):  13612c79b39396721e7a65af393b4dc71cf951ae9905cf80865a1d945048b39b
    derived (union diff): 9e4e0f6251a43b0b552239e209421b720ce9733123dbc1f0f7ec490772dd2203

**The gate is working correctly.** It is reporting, accurately, that a commit on `main` does
not attest to its own diff. The design assumed commits survive; squash rewrites them.

**Do not "fix" this with an allowlist or a revert.** History cannot be rewritten
(non-fast-forward, no bypass actors — deliberate), and a revert would be one more
trailer-less commit. Both gate paths are already **bounded ranges**, verified:

    push:        github.event.before..github.sha
    pull_request: origin/<base>..github.event.pull_request.head.sha
    new branch:  github.sha~1..github.sha

Neither scans history. So the next rebase-merged commit has range `bbc4372..new`, which
**excludes** `bbc4372`, and `main` goes green on its own. If you find either path scanning
all history, that is a real defect — fix it.

**Recurrence is prevented at the platform**, not by convention. Ruleset 22066749, verified
by API immediately before this commit:

    allowed_merge_methods:   ["rebase"]
    required_linear_history: true
    enforcement: active   bypass_actors: []   (administrators are not exempt)
    deletion + non_fast_forward blocked, PR required, strict: true
    9 required contexts == 9 live "Gate -" jobs, exact match

Merge method is **rebase**. Squash or merge-commit on an attested branch is a defect.

## 3. Probes are the thing that keeps failing — read this before experimenting

Three times a *probe* gave a wrong answer while the change under test was fine. This is why
`CLAUDE.md` §4b exists.

1. **A probe reported IDENTICAL over two empty lists.** Testing whether SPDX headers change
   compiled output, in a fresh worktree with no `_build`, so `find` matched nothing and two
   empty files compared equal. The real answer, measured across 2,211 beams, is that headers
   **do** change raw `.beam` output because `debug_info` embeds line numbers.
2. **Three mutations never applied and were scored as survivors.** Regex escaping silently
   failed to match, so the harness measured unmutated code and reported a perfect-looking
   result. `tools/mutate.sh` now proves application three ways and aborts on a CANARY row
   whose pattern is deliberately absent.
3. **`:beam_lib.strip/1` writes the stripped beam back to disk.** It is not a pure function.
   A stripped-equivalence experiment stripped `debug_info` out of the real `_build/dev`, and
   dialyzer then failed with "Could not get Core Erlang code". Fixed by a clean rebuild.

**Standing rule (CLAUDE.md §4b): probes run against a copy.** Any experiment touching
`_build`, `deps`, `.git` or tracked files runs in a throwaway worktree or a copied `_build`,
never the working one, and **the PLAN names where the probe runs before it runs.**

## 4. Order of work

**Release, then licensing (14) when unblocked, then presentation.** Nothing else starts
until the tag exists.

Slice 14 is **blocked** on two inputs only the owner can supply: the exact registered entity
name, character for character, and the copyright assignment date.

## 5. Slice 14 — licensing, planned and blocked

One commit changes `LICENSE`, `NOTICE`, and SPDX headers on all ~273 tracked files.

- Headers: `SPDX-FileCopyrightText: 2026 <registered name>` — **holder only**. The header is
  a rights statement, not a credit line.
- `LICENSE` and `NOTICE` copyright line become the holder.
- `NOTICE` additionally carries the builder credit and the original author and inventor with
  ORCID `0009-0008-9457-2160`. NOTICE is the file Apache-2.0 requires downstream users to
  preserve, so that is where builder and author names travel with the code.
- `PROVENANCE.md`: authorship, build name, assignment with date, developed at private
  expense, patent holder.

**Its exit criterion was corrected, and the correction matters.** "Byte-identical `.beam`
output" **cannot pass** — `debug_info` embeds line numbers, so two header lines shift every
module. Three independent proofs replace it:

1. **Stripped-beam equivalence** — compare with debug and line chunks removed. Verified
   **IDENTICAL across 2,178 beams**. Proves semantics unchanged. *Strip against a copy.*
2. **Diff-shape** — every added line is a comment, nothing removed or modified. Provable
   from the diff alone, so a reviewer needs no build.
3. **Count assertion** — every in-scope file gained exactly one header and none gained two,
   so re-running the script cannot silently double up.

## 6. The release slice — five confirmed blockers

`mix release` does not boot today. None of these is the manual `ensure_all_started` sequence
the docs imply; every app already declares a proper `mod:`.

1. `config/runtime.exs` raises unconditionally in `:prod` — `HACKTUI_START_REPO` defaults
   false, so the guard errors before any application starts.
2. With env set, `start_repo: true` makes `Repo` a permanent child; an unreachable DB halts
   the release.
3. The `hacktui_sensor` release contradicts its own comment: its `.app` lists `hacktui_hub`,
   which pulls `hacktui_store`, so the standalone sensor also demands DB credentials.
4. No TUI entry point exists in a release — the only path to the dashboard is a Mix task,
   and Mix is not in a release.
5. `config/config.exs` reads `System.get_env` at **build** time, baking build-host DB values
   into `sys.config`.

**Exit:** boots from a **clean clone** with no manual sequence; then a **signed, annotated**
`v0.1.0` tag and a **GitHub Release** whose notes list what is qualified, link
`docs/not_production_ready.md`, and state the SPDX/Apache boundary.

## 7. Repo presentation — eight items

1. **README "currently supports" must match the code.** *Corrected from the original brief:*
   there are **three** collectors, not one — `Collectors.Network`
   (`collectors/network.ex`), `Collectors.ProcessSignals` (`hacktui_sensor.ex:75`) and
   `Collectors.Journald` (`hacktui_sensor.ex:170`). All three are wired and supervised, so
   the test "name the module that does it or drop it" **passes for all three** and the
   bullets are not false. The real defect: both non-network collectors are opt-in via
   `HACKTUI_SENSOR_JOURNALD` / `HACKTUI_SENSOR_NETWORK`, and those variables are documented
   **nowhere** — no `.md`, not `.env.example`. Someone following the docs can never enable
   them. **Fix is documentation, not relocation**, plus a note that two collectors are
   structurally hidden inside the parent module.
2. **Label detection as scaffolding.** `DetectionService` is a thin delegate; no rule layer,
   no rule format, no coverage table. `attack_mapping/1` (`purple_service.ex:28-29`) is two
   clauses — `T1071.004` for `"alert_observed"` and a `T1087` fallthrough. Add a status note
   to `PURPLE_TEAM_MODEL.md` so it does not imply detection validation exists, and a TODO on
   `attack_mapping/1` marking it a placeholder.
3. **`docs/standards_mapping.md`, design intent only.** Observation kinds to OCSF event
   classes (`network.flow`, `journald.auth`, `journald.security`, `system.error`); alerts and
   cases to OCSF findings; `contain`/`observe`/`notify_export` to CACAO action types;
   receipts as the evidence attachment on an alert. Mark explicitly as mapping, not
   implementation. No code changes.
4. **`ROADMAP.md`: move "proof-carrying alerts and investigations" from Later to Next.**
   Confirmed at line 42 under `## Later`. It is the HolyTrinity hook and the thing that makes
   this an agent-incident-response console rather than a SOC prototype.
5. **Consolidate three demo runbooks into one** — keep `docs/case_1_demo_runbook.md` as the
   walkthrough; fold in `docs/demo_runbook.md` and `docs/demo_terminal_launcher.md`.
   `docs/README.md` already flags them as overlapping.
6. **Release**: covered in §6.
7. **Repo presentation**: About text — *"Terminal-native purple-team SOC on the BEAM. Agents
   propose; a human approves; every effect is auditable."* Topics: `elixir`, `erlang`,
   `beam`, `security-operations`, `soc`, `purple-team`, `mcp`, `ai-agents`, `jido`,
   `apache-2`. Add `SECURITY.md` (how to report, what is in scope), `CITATION.cff` (name,
   ORCID `0009-0008-9457-2160`, version, date), `CHANGELOG.md` seeded from slice history.
   Badges limited to what is true: licence, and CI status from the real gate workflow.
8. **GitHub-setting dependencies are owner work, flagged in the PLAN, never discovered at
   signoff.**

## 8. Owner work — cannot be done from the repo

- GitHub **About** text and **topics** (§7.7).
- **Social preview** image.
- **Publishing** the GitHub Release. The tag can be pushed; publishing is an action under
  the owner's account.
- The **registered entity name and assignment date** for slice 14.

## 9. Things that will bite you

- **`internal/` is gitignored.** Slice PLANs, CRITERIA, FINDINGS and signoffs are local
  only and are not in the published repo. A commit touching only `internal/` stages nothing
  and `commit-msg` will refuse it as "nothing to attest".
- **`internal/incoming/holytrinity.hold-v1.schema.json`** is parked, awaiting the contracts
  slice. It lives there because an untracked `schemas/` blocked the commit gate four times.
- **Renaming a `Gate -` job silently breaks a required check** in the ruleset, and a
  required context that never reports blocks every PR forever. Any slice that renames one
  must put the before/after context names in its PLAN so the ruleset edit is a copy-paste.
- **The integration job is advisory and fails.** 3 failures, not 7 — slice 13's sensor fix
  cleared four. All three are residual-class, and the root cause is the job, not the tests:
  none of the three is tagged `:integration`, so `mix test --include integration` runs the
  whole suite under `HACKTUI_START_REPO=true` and repo-disabled tests fail by construction.
  Three decisions are pre-made: tag what is genuinely `:integration`; run safe-mode tests in
  their own env; and for `Forwarder`, prefer **not** starting it under the application in the
  test env, so tests start it under their own supervision.
- **Reviewers get `CRITERIA.md` before they are spawned**, and must classify every finding
  as blocking or residual. A round finding only residual items is PASS-with-residuals.
  Three-round cap unless a blocking class is hit. An unclassified finding is not actionable.
