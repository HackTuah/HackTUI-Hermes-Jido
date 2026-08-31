# Slice 01 — FINDINGS

Per CLAUDE.md §5: every claim below cites a path, line(s), observed vs expected, and the
verification command **with its real output**. Nothing here is inferred.

Toolchain: Elixir 1.19.2, OTP 28 (erts-16.1.1), PostgreSQL 17 client, tshark + dumpcap
present. Baseline commit: `f0494af` (main).

---

## Gate baseline

Established by running each gate for the first time in the project's history.

| Gate | Command | Result |
|---|---|---|
| compile | `mix compile --warnings-as-errors` | **pass** (exit 0, all 7 apps) |
| format | `mix format --check-formatted` | **pass** (exit 0) |
| secret scan | corrected pattern, see F1 | **pass** (empty) |
| test | `mix test` | **7 failures** / 115 run, 18 excluded |
| credo | `mix credo --strict` | **77 issues** (exit 30): 1 warning, 38 refactoring, 18 readability, 20 design |
| dialyzer | `mix dialyzer --format raw` | **61 warnings** (`Total errors: 61`) |
| deps.audit | `mix do deps.loadpaths + deps.audit` | **13 advisories** across 6 packages, see F4 |
| sobelow | `mix sobelow --root apps/<app> --exit` | **7 findings** in 3 apps, see F5 |

---

## F1 — CLAUDE.md's own secret-scan gate could never pass

- **Location:** `CLAUDE.md:85` (section 10)
- **Observed:** the prescribed `git ls-files | grep -Ei 'env|\.key|\.pem|\.pcap'` is
  unanchored, so `env` matches as a substring and the gate always returns a hit:
  ```
  $ git ls-files | grep -Ei 'env|\.key|\.pem|\.pcap'
  apps/hacktui_core/lib/hacktui_core/observation/envelope.ex
  ```
- **Expected:** empty output, per section 10 ("expect empty"). A gate that can never pass gets
  learned as noise and stops being read.
- **Fix:** anchored pattern, verified empty:
  ```
  $ git ls-files | grep -Ei '(^|/)\.env$|\.(key|pem|pcap|pcapng|p12)$'
  (no output)
  ```
- **Status:** fixed in this slice.

## F2 — Four of seven gates could not run

- **Location:** `mix.exs:11` — `deps: []`
- **Observed:** `credo`, `dialyxir`, `mix_audit`, `sobelow` were not dependencies of the
  umbrella or of any app. `mix credo` returned
  `** (Mix) The task "credo" could not be found`.
- **Expected:** CLAUDE.md section 4 lists all four as mandatory pre-commit gates.
- **Status:** fixed. All four installed and producing output.

## F3 — RETRACTED. `mix dialyzer` works; this finding was false.

**Original claim (wrong):** "every formatter throws before printing ... Reproduced
identically with `--format github`, `--format raw`, `--format dialyxir`."

**What is actually true:** only the two pretty formatters (`short`, `github`) throw on
OTP 28's `:exact_compare`. The **default formatter and `--format raw` both work**:

```
$ mix dialyzer 2>&1 | grep -E 'Total errors|throw'
Total errors: 61, Skipped: 0, Unnecessary Skips: 0
$ mix dialyzer --format raw 2>&1 | grep -c '^{:warn_'
61
$ mix dialyzer --format short 2>&1 | tail -1
    (dialyxir 1.4.7) lib/dialyxir/formatter.ex:42: ...   # throws
```

**How the error was made:** four formatters were tested (`short`, `github`, `raw`,
`dialyxir`); the default was never tested, and a crash in two was generalised to all.
`--format raw` was recorded as exit 2 -- which is dialyzer's normal "warnings found"
status, not a crash -- and misread as failure.

**Blast radius:** the false claim was the sole justification for demoting dialyzer to
advisory, and was propagated to `.claude/gate-baseline.json`, `HANDOFF.md`,
`BACKLOG.md`, and `.github/workflows/ci.yml`.

**Round-2 review caught that this sentence originally read "All four are
corrected" while `BACKLOG.md` was never touched — the false claim survived in
the one file a later slice reads as its work queue. All four are corrected now.**

**Consequence:** dialyzer is now a **real ratchet gate** in `.githooks/pre-commit`,
reading `Total errors: N` from `--format raw`. Baseline: **61**.

This is exactly the class of unverified claim CLAUDE.md section 5 exists to prevent,
and it was committed inside the slice whose purpose is to enforce section 5.

### F3a — Dialyzer's first real finding: dead journalctl guard

- **Location:** `apps/hacktui_sensor/lib/hacktui_sensor.ex:156` and `:210`
- **Observed:** raw output contains
  `{:warn_matching, {~c"lib/hacktui_sensor.ex", 210}, {:exact_compare, [~c"<<_:152>>", :==, ~c"'nil'"]}}`.
  `<<_:152>>` is a 19-byte binary. `@journalctl_path System.find_executable("journalctl")`
  resolves at **compile time**; on this host that is `/usr/bin/journalctl`, exactly 19
  bytes. So `is_nil(@journalctl_path)` at `:210` is provably dead on this build.
  ```
  $ echo -n "/usr/bin/journalctl" | wc -c
  19          # 19 * 8 = 152 bits
  ```
- **Expected:** runtime resolution, as `collectors/network.ex:146` already does for
  `tshark`. Built in a container without systemd, the attribute bakes in `nil` and the
  journald collector is permanently disabled with no diagnostic.
- **Status:** **out of scope for slice 01** (§9). Logged to `BACKLOG.md`; belongs to
  slice 03.

## F4 — 13 dependency advisories, 6 HIGH, one in a direct dependency

- **Command:** `mix do deps.loadpaths + deps.audit` (exit 1). 13 advisories across **6**
  distinct packages (an earlier draft said 7).
- **Observed:**

  | Severity | Package | Advisory |
  |---|---|---|
  | HIGH | postgrex | Channel-name SQL injection in `Postgrex.Notifications.listen/3` |
  | HIGH | plug | Unbounded buffer accumulation in multipart header parsing (DoS) |
  | HIGH | mint | Unbounded CONTINUATION/HEADERS frame accumulation |
  | HIGH | mint | Unbounded streams map growth via PUSH_PROMISE |
  | HIGH | hackney | `ssl:connect/2` post-handshake upgrade has no timeout |
  | HIGH | req | Unbounded archive/compression extraction |
  | MODERATE | decimal, hackney ×2, mint, req | see full log |
  | LOW | hackney, mint | see full log |

  **`postgrex` is a direct dependency** (`apps/hacktui_store/mix.exs:29`,
  `{:postgrex, "~> 0.19"}`, locked at 0.22.0; patched in 0.22.2). The rest arrive
  transitively through `jido → jido_action`'s two HTTP stacks.
- **Expected:** Section 4 requires `mix deps.audit` to pass.
- **Status:** **out of scope for slice 01** (§9). Logged to `BACKLOG.md` as its own
  slice — upgrading `jido` (2.0.0 → 2.3.3) changes the transitive tree and needs its own
  review.

## F5 — sobelow findings, cross-confirmed by independent audit

Seven findings across three apps. Root-level `mix sobelow` reports "This does not appear to be a Phoenix application"
(exit 0), which section 4 anticipates as acceptable. Sobelow itself states umbrella apps
must be scanned individually; doing so surfaces real findings:

| App | Finding | Location |
|---|---|---|
| hacktui_agent | Directory traversal in `File.write!` | `hermes_local.ex:40`, `:41` |
| hacktui_hub | Unsafe `String.to_atom` | `demo/runner.ex:133`, `:135` |
| hacktui_hub | Unsafe `String.to_atom` | `query_service.ex:163` |
| hacktui_hub | Directory traversal in `File.stream!` | `replay/loader.ex:10` |
| hacktui_sensor | Unsafe `String.to_atom` | `forwarder.ex:203` |

Four of the five `String.to_atom` sites and the `hermes_local.ex` traversal were
independently identified by the security and correctness audits; `replay/loader.ex:10`
is **new** and was found only by sobelow.

- **Status:** out of scope here; logged to `BACKLOG.md` for slices 07/08.

## F6 — `mix.lock` had three orphaned entries

- **Observed:** `castore`, `ex_ratatui`, and `rustler_precompiled` were locked but absent
  from `deps/` and unreachable from any `mix.exs`, so a reviewer's first `mix deps.get`
  rewrote the lockfile and dirtied a clean checkout.
- **Fix:** `mix deps.unlock --unused`. Verified stable:
  ```
  $ mix deps.get; git hash-object mix.lock   # run twice, identical
  aaa7812ed4450dcdb00f692e4c4ffa91fae104e4
  ```
  Every remaining lock entry now has a matching `deps/` directory.
- **Status:** fixed.

## F7 — `.env.example` was referenced but absent

- **Observed:** `.gitignore:28` carries the negation `!.env.example`, but the file did
  not exist. Runbooks in `docs/demo_runbook.md`, `docs/operator_boot_runbook.md`,
  `docs/db_integration_qualification.md`, and `docs/failure_modes_and_recovery.md`
  instruct `source .env`, so a fresh clone hard-stops at step 1.
- **Fix:** added, documenting all 10 environment variables actually read by
  `config/` and `apps/*/lib`. Verified trackable (`git add --dry-run` succeeds) while
  `.env` itself remains ignored.
- **Status:** fixed.

## F8 — Correction: Credo does **not** catch the precedence bug

- **Claim under test:** the approved plan and the OSS audit both predicted
  `mix credo --strict` would flag the `||`/`|>` precedence defect at
  `apps/hacktui_hub/lib/hacktui_hub/query_service.ex:286-303`.
- **Observed:** it does not.
  ```
  $ grep -n "query_service.ex:2[89]" credo.log
  (no output)
  ```
  Credo's 77 findings do not include those lines. Dialyzer does not flag them either.
- **Consequence:** that bug — which crashes the MCP transport — would **not** have been
  caught by any gate in CLAUDE.md §4. The slice-01 rationale that "Credo catches this
  class of defect" is **false as stated** and is corrected here.
- **Status:** recorded. Slice 04 must fix the bug directly and add a regression test;
  it cannot rely on a linter to find recurrences.

---

## F9 — Round-1 review: the ratchet failed OPEN in three ways

Both independent reviewers returned **FAIL**. Reproduced locally before accepting:

```
$ now=$(grep -oE '[0-9]+ failures?' /dev/null | grep -oE '^[0-9]+' | paste -sd+ | bc 2>/dev/null || echo 0)
$ now=${now:-0}; [ "$now" -gt 7 ] && echo BLOCKED || echo PASSES
PASSES          # a crashed `mix test` printed "improved: 0 < 7"

$ b=$(grep -oE '"test_failures"[^0-9]*[0-9]+' .claude/NOPE.json 2>/dev/null || echo "")
$ [ -n "$b" ] && echo "runs" || echo "SKIPPED, fail stays 0"
SKIPPED, fail stays 0     # deleting the baseline silently disabled every ratchet

$ grep -c dialyz .githooks/pre-commit
0               # PLAN promised a dialyzer ratchet; none existed
```

Reachability of the first case is not theoretical: no app sets `elixirc_paths`, so
`mix compile --warnings-as-errors` compiles `lib/` only and never sees `test/`. A syntax
error in any `test/*.exs` produces exactly the no-summary log that scored as "improved".

**Fixed:** each ratchet now requires its gate to emit a recognisable summary line and
hard-fails when absent; a missing or unparsable baseline hard-fails; the dialyzer ratchet
is implemented against `Total errors: N`.

## F10 — Round-1 review: further defects, all confirmed

| # | Defect | Verification | Fix |
|---|---|---|---|
| a | `Merge ` prefix bypassed the slice-reference gate entirely | `commit-msg <(echo "Merge anything")` → exit 0 | anchored to git's real generated forms |
| b | credo ratchet summed 4 of credo's **5** categories, ignoring `consistency` — 8 such checks are enabled | `grep 'issue", "' deps/credo/.../summary.ex` shows 5 | all five summed |
| c | `preferred_cli_env` was inert because `def cli/0` exists; local ran `:dev`, CI `:test` → incomparable baselines | PLT filename is `..._deps-dev.plt` | key removed; both pinned to `:dev` |
| d | `grep -c ... \|\| echo 0` emitted `"0\n0"` when the audit crashed | `n=$(grep -c X /etc/hostname \|\| echo 0)` → two lines | `\|\| n=0` on the assignment |
| e | Gates measured the working tree, not the index | no `checkout-index`/`worktree` in hook | hook now refuses to run with unstaged changes to tracked files (section 4 forbids `git stash`) |
| f | CI could not fail on any ratcheted gate and never read the baseline | `grep gate-baseline ci.yml` → empty | CI now compares against the baseline |
| g | `grep -EiC0` — valid but meaningless noise in a security line | — | dropped |
| h | Predictable `/tmp/hacktui_gate_*.log` paths, symlink-attackable | — | `mktemp -d` + trap |
| i | Hooks were opt-in per clone; nothing installed them | `core.hooksPath` is local config | `mix setup` installs them |
| j | Section citations were line numbers (`§44`, `§85`) | `grep '^## ' CLAUDE.md` → sections 0–10 | corrected throughout |

**Not fixed, accepted as a known limitation:** the ratchet compares a scalar, so fixing
three failures while introducing three others nets to "held at 7" and passes. Recorded
in `BACKLOG.md`.

## F11 — Hook block behaviour, verified by attempting commits

> **Round-3 review correction:** cases 1–4 below were recorded against the hook as it
> existed at the time of each attempt, and the hook has since been rewritten twice. They
> are **historical transcripts**, not current output — the wording of the block messages
> has changed. Case 5 and F12 are current. This is logged because presenting stale output
> as current evidence is precisely what section 5 forbids.

Round-2 review correctly flagged that PLAN.md claimed "verified by attempting one" while
citing an F9 that contained no such transcript. The actual runs are recorded here.

**1. Commit message without a slice reference — rejected**
```
$ git commit -m "add some governance stuff"
== CLAUDE.md section 4 commit gates ==
  compile                pass
  ...
Gates OK.
COMMIT REJECTED -- CLAUDE.md section 7
  Subject must be:  NN-kebab-name: <imperative summary>
exit=1
```

**2. Deliberately broken formatting — rejected by two independent gates**
```
$ printf 'defmodule    GateProbe   do\n  def   x,   do:    1\nend\n' >> apps/hacktui_core/lib/hacktui_core.ex
$ git add -A && git commit -m "01-governance-gates: probe the format gate"
  format                 FAIL -- run: mix format
  credo (ratchet)        REGRESSION: 78 issues > baseline 77
COMMIT BLOCKED -- a hard gate failed or a ratchet regressed.
exit=1
```
Note the credo ratchet caught the same change independently of the format gate.

**3. Valid commit — allowed**
```
$ git commit -F <message with slice prefix>
  compile                pass
  format                 pass
  secret scan            pass
  test (ratchet)         held at 7 (baseline 7)
  credo (ratchet)        77 (baseline 77)
Gates OK.
exit=0   -> db3ceff
```

**4. Sign-off gate — blocks the implementer's own commit**
```
$ git commit -m "01-governance-gates: fix round-1 review findings"
  review signoff  FAIL -- no docs/slices/*/REVIEW.signoff.
                  CLAUDE.md section 0: you may not certify your own diff.
COMMIT BLOCKED
exit=1
```

**5. Fail-closed paths** (round-2 findings, fixed and re-verified)
```
crashed gate, no summary line   -> HARD FAIL (unmeasurable)   [was: "improved: 0 < 7"]
baseline file missing            -> HARD FAIL (no baseline)    [was: silently skipped]
non-integer count ("abc", "", "7\n3") -> HARD FAIL             [was: "held at abc", pass]
sha256sum unavailable            -> HARD FAIL                  [was: grep -q "" matched]
credo clean ("found no issues")  -> 0                          [was: gate unsatisfiable]
injected regression 99 failures  -> REGRESSION 99>7
```

## F12 — Round-3 review (fresh reviewer, no prior context)

Per the maintainer's definition, independent review means a reviewer spawned with no
knowledge of previous rounds, reviewing everything rather than a diff. That reviewer
returned **FAIL** and found three blockers the two previous rounds missed.

**H1 — a *truncated* test log scored as an improvement.** Earlier rounds fixed the
*empty*-log case; a partial log still passed. `mix test`'s exit status was discarded by a
`;`, so a run that aborted after 3 of 7 apps summed to fewer failures and read as progress:
```
$ n=$(mix test 2>&1 | sed '/^==> hacktui_hub/,$d' | grep -oE '[0-9]+ failures?' \
      | grep -oE '^[0-9]+' | paste -sd+ | bc); echo $n
2                      # vs baseline 7 -> "improved" -> COMMIT ALLOWED
```
Fixed: the status must be 0 or 2 (ExUnit's pass / tests-failed), and the log must carry at
least one summary per app with a `test/` directory. Re-verified:
```
truncated log          -> HARD FAIL
full log               -> 7
exit status 1 (compile error) -> HARD FAIL
```

**H2 — `mix hex.audit` was mislabelled and its baseline unrecorded, hiding a HIGH CVE.**
The hook reported it as "retired packages present". It reports security advisories, and
strictly more of them than `deps.audit`:
```
$ mix hex.audit    | grep -cE '^  [a-z_]+ [0-9]'    -> 23 advisories, 7 packages
$ mix deps.audit   | grep -c '^Name:'               -> 13 advisories, 6 packages
$ mix hex.audit | grep -A2 hpax
  hpax 1.0.3 - EEF-CVE-2026-58226 (HIGH)
    Unauthenticated denial-of-service via unbounded HPACK integer decoding in hpax
```
`hpax` appeared in **no** artifact in this repository. For a platform whose own threat
model names an unauthenticated MCP server, an unrecorded unauthenticated-DoS HIGH is not
cosmetic. Fixed: label corrected, baseline recorded (23/7), `hpax` logged to BACKLOG.

**H3 — CLAUDE.md section 4 was still false.** It claimed three gates do not pass; five do
not. `deps.audit` and `hex.audit` are advisory with no ratchet, so a newly introduced
vulnerability fails nothing. Section 4 now says so explicitly.

Also fixed from that round: local baseline-monotonicity enforcement (previously CI-only
and PR-only); CI's credo step would have hard-failed forever once credo reached zero;
CI's baseline step skipped rather than failed when the base ref was unreadable; stale
counts in `BACKLOG.md` and a `§85` citation in `HANDOFF.md`; a `PLAN.md` round-status
contradiction; the `commit-msg` comment that claimed no text-based exemptions while
`fixup!`/`squash!` are exactly that; and `mix cmd --app`, deprecated in Elixir 1.19.

**Deferred to BACKLOG (not fixed here):** the scalar-ratchet weakness, `deps.audit`/
`hex.audit` having no ratchet, CI not checking commit messages or sign-off, CI not running
on `slice/*` pushes, the `fixup!` text exemption, `.credo.exs` being gameable (and
`Credo.Check.Warning.UnsafeToAtom` being disabled in the stock config while four unsafe
`String.to_atom` sites are known), and contributor docs not mentioning `mix setup`.

## F13 — Round-4 review (fresh context, on the pushed commit `563b26c`)

The commitment recorded in `REVIEW.signoff` — that slice 02 would open with a
fresh-context review of this commit — was honoured. It returned **FAIL** and found three
items the previous three rounds missed, one of them self-inflicted in round 3.

**B1 — `mix setup` could not install the hooks. Self-inflicted in round 3.**
Round 3 flagged `mix cmd --app` as deprecated. The "fix" changed it to `mix do --app`.
But `mix cmd` runs *shell commands* and `mix do` runs *Mix tasks* — there is no `git`
Mix task:
```
$ mix do --app hacktui_core git config --get core.hooksPath
** (Mix) The task "git" could not be found
```
So the slice's only installation mechanism was broken, and `CLAUDE.md`, `PLAN.md`,
`HANDOFF.md` and `FINDINGS.md` all asserted it worked. On a fresh clone the slice
delivered no gate at all. A working call was replaced with a non-functional one while
chasing a warning. Restored to `mix cmd --app`; verified:
```
$ git config --unset core.hooksPath && mix setup >/dev/null 2>&1; echo $?
0
$ git config --get core.hooksPath
.githooks
```
(`mix cmd --app` emits 7 deprecation warnings — one per umbrella app — and works. The
warning was never the problem.)

**H2 — the `_corrections` escape hatch matched a numeric *prefix*.** `$o` was unanchored,
so a correction recording `"from": 77` authorised a `7 -> 8` raise on a different key,
while printing the reassuring message that a correction was on record:
```
  ACCEPTED as documented correction (o=7 matched from:77)
```
Fixed: `from` is anchored with `[^0-9]` and `to` must equal the new value. Re-verified —
the synthetic collision is rejected and the real `60 -> 61` correction still passes.

**M3 — two fixes claimed in three documents were never applied.** `HANDOFF.md:12` still
carried a `§85` line-number-as-section citation and `:14` still said "Three of them do not
pass" after `CLAUDE.md` was corrected to five. `FINDINGS.md` F10j/F12 and `REVIEW.md` both
listed these as fixed. Same class as F3 and B3 — a claimed fix that did not land.

Also fixed from that round: CI's test ratchet lacked the exit-status and per-app
completeness guards the hook gained in round 3, so `CLAUDE.md`'s "CI repeats the same
baseline comparison" was false (H1); `improved` was a pass that left permanent slack, so
the ratchet never tightened (M5 — now a hard failure demanding the baseline be lowered in
the same commit); ignored files under source paths were invisible to the working-tree
check (M7); the sign-off hash omitted binary content and `core.abbrev` (M6); "clean"
phrases were matched unanchored anywhere in a log (L1); the hex.audit line hard-coded
"incl. hpax HIGH" and would lie once patched (L3); `preferred_envs: [ci: :test]` made
`mix ci` contradict the comment two lines above it (L4); and `.claude/hooks/` was an empty
untracked residue of the abandoned settings.json approach.

**Recorded as accepted limits rather than fixed:** merge/rebase/cherry-pick commits run no
`pre-commit` gate at all (`githooks(5)`), and the sign-off hash cannot be fully pinned
against `.gitattributes` diff drivers. Both in `BACKLOG.md`.

The reviewer's amended capability statement is adopted: *a competent regression detector
for a cooperating author, no assurance against a non-cooperating one — and, as shipped in
`563b26c`, not even installed for a cooperating author who follows the documented setup.*
