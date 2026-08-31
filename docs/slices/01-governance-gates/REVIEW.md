# Slice 01 — REVIEW

Per CLAUDE.md sections 0 and 8, the implementer may not certify their own diff. Two
independent reviewers ran read-only against the raw diff. Neither edited code.

## Round 1 — `f0494af..db3ceff`

**Both reviewers returned FAIL.** Independently, on disjoint briefs, they converged on
the same core defect: the gate machinery could be made to pass while the gate underneath
it was broken or absent.

### Reviewer A — governance compliance and evidential honesty
Verdict: **FAIL**

Blockers:
1. `CLAUDE.md:44` named `.claude/settings.json`, which does not exist — and CLAUDE.md was
   *added by this commit*, so the diff introduced a false normative statement about its
   own deliverable.
2. No `REVIEW.md`/`REVIEW.signoff`; the sign-off gate in CLAUDE.md section 4 was
   unimplemented, so the slice installing the gates violated the gate it installs.
3. Hooks opt-in per clone; nothing installed them.
4. Ratchet scored a crashed gate as an improvement.
5. Deleting the baseline silently disabled every ratchet.

High: `FINDINGS.md` F3 was false — `mix dialyzer` works; the dialyzer ratchet promised in
PLAN.md was never implemented; `hex.audit`/`sobelow` absent from the hook; dialyzer count
60 vs actual 61.

Reviewer A's summary judgment, accepted verbatim: *"not a bypass by design — it is a
bypass by omission, which under section 0 is the same outcome."*

### Reviewer B — shell/CI correctness and supply chain
Verdict: **FAIL**

Independently found all of the above, plus:
- credo ratchet summed 4 of credo's **5** summary categories, ignoring `consistency`
  (8 such checks enabled) — vacuous for that whole category.
- `Merge ` prefix bypassed the slice-reference gate outright.
- `preferred_cli_env` inert because `def cli/0` exists; local ran `:dev` and CI `:test`,
  making the two baselines incomparable.
- CI could not fail on any ratcheted gate and never read the baseline; the `integration`
  job never ran on PRs (`github.ref` is `refs/pull/N/merge`); the PLT cache key omitted
  the toolchain that dialyxir embeds in the PLT filename; `hex.audit` never ran.
- `grep -c … || echo 0` produced a malformed two-line count on crash.
- Gates measured the working tree, not the index.
- Predictable `/tmp` log paths; `grep -EiC0` noise.
- Section citations were line numbers (CLAUDE.md has sections 0–10 only).

### Confirmed correct by both reviewers
The 7-failure and 77-issue baselines and the hook's counting for both; 13 advisories /
6 HIGH; `postgrex` a direct dependency; F3a's journalctl dead-guard proof; F8 (Credo does
not catch the precedence bug); lockfile stability; `.env.example` matching exactly the 10
variables the code reads; **section 9 scope discipline — zero files under `apps/`
changed**; and that `.credo.exs`/`.dialyzer_ignore.exs` were not gamed to make gates pass.

### Disposition
Every blocker and HIGH was independently reproduced by the implementer before being
accepted — see `FINDINGS.md` F9 and F10 — and fixed. F3 is retracted in place rather than
deleted, so the error stays visible.

## Round 2 — staged fix diff

**Both reviewers returned FAIL again.** They confirmed all five round-1 blockers were
genuinely closed — including a strong fail-closed proof (running the hook with `mix`
removed from `PATH`: every ratchet hard-failed) — and independently reproduced all five
baseline numbers. What failed was a recurrence of the round-1 *class*: claims in the diff
about its own deliverable that were not true.

New blockers, all reproduced by the implementer before acceptance:

| # | Defect | Status |
|---|---|---|
| B4 | Sign-off gate failed **open** when `sha256sum` was unavailable: empty hash, `grep -q ""` matched any file | fixed — hash must match `^[0-9a-f]{64}$` |
| F-1 | Non-integer count fell through `if/elif` into `else` → "held at abc" → commit allowed | fixed — `is_uint` guard; pass is no longer a fallthrough |
| B3 | F3's retraction claimed "all four corrected" while `BACKLOG.md` still carried the false claim | fixed — purged, and the sentence corrected |
| B1 | PLAN.md checked "Hook permits this slice's own commit" while the hook exits 1 | fixed — unchecked, with the reason |
| B2 | PLAN.md cited FINDINGS F9 for an attempted-break transcript that did not exist there | fixed — recorded as F11 |
| B5 | CI ran credo/dialyzer under `MIX_ENV=test` against `:dev`-recorded baselines | fixed — pinned to `:dev`; PLT cache key now includes the env |
| H1 | CLAUDE.md section 4 still read "ALL of these pass"; "ratchet"/"baseline" appeared nowhere in it | fixed — section 4 now describes the deviation and the limits of hook enforcement |
| H2 | Nothing prevented a baseline being **raised** | fixed — CI compares against the base ref |
| H3 | Credo reaching zero would make the gate permanently unsatisfiable | fixed — "found no issues" → 0 |
| L1 | The `grep -c … \|\| echo 0` defect F10d claimed fixed was still present at the sobelow site | fixed |
| M1 | `trap` deleted the diagnostic logs before the operator could read them | fixed — kept on failure |
| M2 | Index check ignored untracked files | fixed — `--untracked-files=normal` |
| M3/M4 | Sign-off could be untracked; hash varied with git config | fixed — must be tracked; diff config pinned |
| F-4 | `Merge branch x` typed by hand still bypassed the slice rule | fixed — exemption gated on `MERGE_HEAD`/`REVERT_HEAD`/`CHERRY_PICK_HEAD`, and the slice directory must exist |

Reviewer B's capability assessment is accepted and recorded in `BACKLOG.md`: this is
**a solid regression detector and a weak authorization control**. The sign-off gate
cannot bear the weight CLAUDE.md section 0 places on it; branch protection with required
reviewers is the real control and is not yet configured.

## Round 3 — fresh reviewer, no prior context

The maintainer defined independent review as **a reviewer spawned with no knowledge of
previous rounds, reviewing everything rather than a diff**. Round 3 was run that way and
returned **FAIL**, finding three blockers the two previous rounds — four reviewers — had
missed:

| # | Blocker | Why it mattered |
|---|---|---|
| H1 | A *truncated* `mix test` log scored as an improvement (`improved: 2 < 7`). Rounds 1–2 fixed the *empty*-log case; `mix test`'s exit status was discarded by a `;`, so a run aborting after 3 of 7 apps read as progress | The slice's own load-bearing property — "absence of a summary is a hard failure, never a pass" — was only true for total absence |
| H2 | `mix hex.audit` was labelled "retired packages present"; it reports **security advisories**, 23 across 7 packages vs `deps.audit`'s 13/6. The delta includes `hpax 1.0.3` / `EEF-CVE-2026-58226` **(HIGH, unauthenticated DoS)** — which appeared in **no** artifact in this repo | An unrecorded unauthenticated-DoS HIGH in a platform whose threat model names an unauthenticated MCP server |
| H3 | CLAUDE.md section 4 claimed three gates do not pass; **five** do not — `deps.audit` and `hex.audit` are advisory with no ratchet | The governing document was false again, the third round running |

All three are fixed and re-verified (FINDINGS F12). Also fixed: local baseline
monotonicity (was CI-only and PR-only), CI's credo step hard-failing forever once credo
goes clean, CI's baseline step skipping rather than failing on an unreadable base ref,
stale counts, a `§85` citation, a PLAN round-status contradiction, a false `commit-msg`
comment, and a deprecated `mix cmd --app`.

The reviewer's capability statement is adopted verbatim into `CLAUDE.md` and `BACKLOG.md`:
**a competent regression detector for a cooperating author, and no assurance at all
against a non-cooperating one.**

### Disposition

Per the maintainer's instruction — one more round, then commit either way — this slice is
committed with round 3's blockers fixed and its residual findings logged to `BACKLOG.md`.

**The fixes for round 3's blockers have not themselves been reviewed.** That is a real
gap, stated here rather than papered over. Slice 02 should open with a fresh reviewer
pass over this commit before new work builds on it.
