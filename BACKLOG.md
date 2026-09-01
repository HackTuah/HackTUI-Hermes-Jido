# Backlog

This backlog is a phased roadmap. Items listed as future phases are planned direction, not implemented capability.

## Found by the slice-01 gate baseline (2026-08-31)

First run of `credo`, `dialyzer`, `deps.audit`, and `sobelow` in the project's history.
Evidence and commands: `docs/slices/01-governance-gates/FINDINGS.md`. Logged per §9
rather than fixed in slice 01.

- **Dependency advisories — 13 across 6 packages via `deps.audit`; 23 across 7 via
  `mix hex.audit`, which is a strict superset.** Includes a HIGH
  channel-name SQL injection in `postgrex` (`GHSA-r73h-97w8-m54h`), which is a *direct*
  dependency at `apps/hacktui_store/mix.exs:29` (locked 0.22.0, patched 0.22.2). The
  rest are transitive through `jido -> jido_action`'s two HTTP stacks. Needs its own
  slice: bumping `jido` 2.0.0 -> 2.3.3 reshapes the transitive tree.
- **`hpax 1.0.3` — `EEF-CVE-2026-58226` (HIGH), unauthenticated denial-of-service via
  unbounded HPACK integer decoding.** Reported by `mix hex.audit` but **not** by
  `mix deps.audit`, which is why it was missing from every artifact until round-3 review
  caught it. Transitive via the HTTP stacks under `jido_action`.
- **Path traversal, `apps/hacktui_hub/lib/hacktui_hub/replay/loader.ex:10`** —
  `File.stream!` on an unvalidated resolved path. Found only by sobelow.
- **Path traversal, `apps/hacktui_agent/lib/hacktui_agent/hermes_local.ex:40-41`** —
  `case_id` reaches `Path.join` unchecked.
- **Unsafe `String.to_atom` on DB/env-derived values** —
  `demo/runner.ex:133,135`, `query_service.ex:163`, `forwarder.ex:203`.
- **Dead compile-time guard, `apps/hacktui_sensor/lib/hacktui_sensor.ex:156,210`** —
  `@journalctl_path` resolves at compile time, so `is_nil/1` at :210 is provably dead;
  a build without systemd bakes in `nil` and silently disables journald collection.
  Proven by Dialyzer. Belongs to slice 03.
- **`mix dialyzer --format short` / `--format github` crash** on OTP 28's
  `:exact_compare` (dialyxir 1.4.7). The default and `--format raw` formatters work and
  are what the gate uses, so this is cosmetic. An earlier draft of this entry claimed
  dialyzer could not run at all; that was false and is retracted (see slice 01 F3).

## Found by the batched review of slices 02-06

- **`disposition` is plumbed but only partly rendered.** It now reaches the MCP tools and
  the TUI alert-queue workflow, but `live_dashboard_view.format_alert_row/5` still renders
  only severity, title, actor label and threat score — so the live dashboard still shows a
  triaged alert as untriaged.
- **`AlertProjector` is dead code that would destroy decisions if wired up.** It hardcodes
  `state: "open"` on every projection including the update branch, and its insert
  changeset is invalid (`disposition: can't be blank`), so it could never have inserted.
- **`ReadModels.alert_queue_query/0` is a second, drifted definition of the alert queue** —
  it omits `disposition` and hardcodes `state: fragment("'open'")`, while
  `AlertQueueProjection.fields/0` declares `:disposition` is part of the read model.
- **`runtime.ex` still excludes `acknowledged` from correlation** (`alert.state in
  ["open", "investigating"]`), so an acknowledged alert stops absorbing correlated
  observations and new rows appear for signal an analyst already triaged.
- **Atom clauses in the normalisers pass any atom through unvalidated**, including the
  non-canonical `:benign`/`:malicious`. Only the binary clause is domain-derived.
- **The transition guard is case-sensitive** while the normaliser downcases, so a row whose
  stored state is not lowercase would be permanently un-transitionable. Latent: all
  in-repo writers emit lowercase.
- **A zero-row approval reports `:already_decided` even when the row does not exist**, so a
  mis-keyed id gives a misleading error.

## Found during slice 06 (decision integrity)

- **The new approval/transition guards are unexercised against a live database.** They
  are unit-tested against stubs; no concurrent-approval test exists because the
  `:integration` path has never run. The TOCTOU race is closed by construction, not by
  demonstration.
- **The correlation read-modify-write is still unguarded** (`runtime.ex`), so `hit_count`
  and `observation_refs` -- the evidence-linkage field -- are still lost under
  concurrency. Slice 07.

## Found during slice 05 (MCP boundary)

- **`to_json_value/1` stringifies atoms**, so booleans are type-mangled on every tool
  response: `requires_approval` returns as `"true"`, not `true`. Fixing it changes the
  shape of every MCP response and should land with a schema-conformance pass.
- **`PrivacyMask` is too narrow to rely on.** It recognises only RFC1918 and loopback
  IPv4. Public IPs, hostnames, DNS names, TLS SNI and URIs pass through unmasked, and
  free text in `raw_message` is not redacted at all — so `MCP.Egress` masks by field
  name over a weak primitive. Broaden the primitive.
- **Prompt-injection channel remains open.** An adversary who can write bytes into a
  monitored log or wire reaches `raw_message` (`hacktui_sensor.ex:261`), which
  `get_sensor_logs` returns verbatim (`query_service.ex:461`) into an analyst's model
  context. `THREAT_MODEL.md:37-45` names this risk; nothing yet mitigates it.
- **`shutdown`/`exit` in `server.ex` are LSP methods, not MCP.** Dead code; real clients
  terminate by closing stdin.

## Accepted limits of the slice-01 commit gate

Reported by round-2 review, deliberately not fixed in slice 01. Each is a real residual
risk, recorded so it is a known limit rather than an unexamined assumption.

- **The `REVIEW.signoff` gate cannot prove a review happened.** It proves only that a
  sha256 of the staged diff was written into a tracked file — which the implementer can
  do in one command. There is no second identity and no key the implementer does not
  hold. Real enforcement of CLAUDE.md section 0 needs branch protection with required
  reviewers and CODEOWNERS on the remote; `main` currently has no protection configured.
  **This is the largest remaining governance gap.**
- **The ratchet is scalar.** Fixing three failures while introducing three others nets to
  "held at 7" and passes. Identity-level tracking (which tests fail) would close it.
- **CI does not check the commit message or the sign-off**, and only triggers on `main`
  and pull requests — pushes to `slice/*` branches run nothing until a PR exists.
- **The `integration` job cannot fail the build** (`continue-on-error: true`); the 18
  DB-backed tests have never run in CI.
- **`fixup!`/`squash!` subjects are exempt** from the slice-reference rule and are not
  verified to be squashed later.
- **`deps.audit` and `hex.audit` have no ratchet.** Both have a recorded baseline (13 and
  23) but nothing fails on them, so a newly introduced vulnerability blocks nothing.
- **`.credo.exs` is gameable** — unlike dialyzer, whose `Total errors` is a pre-filter
  count, the credo number drops when checks are disabled and nothing guards the config.
  Note `Credo.Check.Warning.UnsafeToAtom` is disabled in the stock generated config while
  four unsafe `String.to_atom` sites are already known.
- **Contributor docs never mention `mix setup`.** `README.md`, `CONTRIBUTING.md`, and
  `DEVELOPMENT.md` do not tell a contributor to install the hooks, so a fresh clone has
  no local enforcement.
- **Merge, rebase and cherry-pick commits run no pre-commit gate.** Per `githooks(5)`,
  `pre-commit` fires only for `git commit`; `commit-msg` additionally exits 0 whenever
  `MERGE_HEAD`/`REVERT_HEAD`/`CHERRY_PICK_HEAD` exists. So `git merge --no-ff` lands a
  tree on `main` with no local gate evaluation.
- **The sign-off hash does not fully pin the diff.** `core.abbrev`, `--binary`,
  `--no-ext-diff` and `--no-textconv` are now pinned, but `.gitattributes` `diff=` drivers
  could still alter hunk text. Fails closed (a mismatch blocks), so this is a
  reproducibility limit, not a bypass.
- **The index-isolation rule forbids partial staging** (`git add -p`). Correct for
  measurement integrity, but a known driver of `--no-verify` habits; worth stating in
  CLAUDE.md as an intended cost.

## Current work

- stabilize the bounded local demo path
- keep investigation, approval, and terminal output deterministic and honest
- preserve safe defaults and avoid parallel implementation paths

## Phase 1: Deterministic replay and regression harness

Planned outcomes:
- deterministic replay inputs for known scenarios
- repeatable expected outputs for alerts, investigations, and approvals
- regression tests that catch detection or investigation drift
- durable fixture and artifact handling for local validation

## Phase 2: Live terminal SOC interface

Planned outcomes:
- richer terminal queue, case, and audit views
- honest runtime health and status visibility
- operator workflows that remain bounded and inspectable
- no claim of a complete production SOC console until verified

## Phase 3: Proof-carrying alerts and investigations

Planned outcomes:
- alerts tied to evidence references and explanation structures
- investigation summaries that show why a conclusion was reached
- durable linkage between detections, evidence, approvals, and outputs
- reduced analyst ambiguity during review

## Phase 4: Slack collaboration and audited delivery

Planned outcomes:
- outbound collaboration as a secondary interface
- durable delivery records and failure visibility
- explicit approval and posting boundaries
- fail-closed provider behavior when not configured

## Phase 5: Purple-team validation loop

Planned outcomes:
- adversary simulation and replay as routine validation inputs
- ATT&CK-aligned exercise metadata and coverage tracking
- expected-vs-observed comparison workflows
- continuous improvement from misses, regressions, and analyst feedback

## Phase 6: Bounded agent assistance

Planned outcomes:
- advisory Hermes workflows for planning, summarization, and improvement proposals
- explicit tool scopes and approval gates
- auditability for agent runs and outputs
- no unchecked autonomous response claims

## Working rules

- build on the existing umbrella boundaries and demo path
- document current capability separately from planned direction
- no fake implementations
- no placeholder security claims
- production-safe defaults only
- prefer deterministic local output over cleverness