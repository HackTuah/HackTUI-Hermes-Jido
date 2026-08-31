# CLAUDE.md — HackTUI Governance & Workflow (standing rules)

HackTUI-Hermes-Jido is an Elixir umbrella (BEAM) purple-team SOC platform, currently a
research prototype being hardened toward production. These rules are non-negotiable.
When a rule here conflicts with a request, follow the rule and say so.

## 0. Prime directive: nothing is "truth" until independently reviewed
No change is accepted, merged, or described as "done"/"fixed"/"working" until an
INDEPENDENT reviewer team has reviewed the raw diff and signed off. Your own summary
is not evidence. Reviews are adversarial: reviewers read the diff fresh, not your story.

## 1. Umbrella map (use real names)
apps/
  hacktui_core/    # commands, events, aggregates, alert+investigation lifecycle
  hacktui_store/   # Ecto/PostgreSQL persistence, projections, audit events
  hacktui_hub/     # control plane: query services, promotion, orchestration, masking
  hacktui_sensor/  # telemetry ingestion: journald, tshark/dumpcap network flows
  hacktui_tui/     # terminal SOC UI
  hacktui_agent/   # Jido runtime (bounded agents) + built-in MCP server
  hacktui_collab/  # experimental collaboration boundary
Requirements: Elixir 1.19+, OTP 28+, PostgreSQL 14+, tshark/dumpcap. Linux-first.

## 2. Work is sliced (see §6). No slice, no code.
Every unit of work is a numbered slice under docs/slices/NN-kebab-name/ with a PLAN.md
approved BEFORE any edit. Commits reference their slice (see §7).

## 3. Plan before editing
For anything touching >1 file or any behavior change, enter plan mode
(`--permission-mode plan` / Shift+Tab) and produce the slice PLAN.md. Do not edit files
until the user approves the plan. Trivial one-line fixes inside an already-approved slice
are exempt.

## 4. Zero-error goal — gates before every commit
A commit is allowed only when ALL of these pass on the umbrella. **Five of them do
not pass yet.** Three (`test`, `credo`, `dialyzer`) are regression-gated; until their baselines in `.claude/gate-baseline.json` reach zero they
are **regression-gated** — a commit is rejected if it makes them worse, and the
baseline may only decrease. This is a recorded, reviewable deviation, not a waiver:
two (`deps.audit`, `hex.audit`) are **advisory only — they have a recorded baseline
but nothing fails a build on them**, so a newly introduced vulnerability is not blocked.
That is a known, recorded gap, not an oversight: see BACKLOG.md and
docs/slices/01-governance-gates/PLAN.md. The gates:
  - mix compile --warnings-as-errors
  - mix format --check-formatted
  - mix test
  - mix credo --strict
  - mix dialyzer            (dialyxir)
  - mix deps.audit          (mix_audit; run mix hex.audit too)
  - mix sobelow --exit      (BEST-EFFORT: no Phoenix app present; may print
                             "not a Phoenix application" — that is acceptable, a crash is not)
  - independent review sign-off matching the exact staged diff (§0)
These are enforced by git hooks in `.githooks/` (install with `mix setup`, which sets
`core.hooksPath`), and by CI, which repeats the same baseline comparison.

Know the limits of that enforcement: `--no-verify` bypasses any hook, `core.hooksPath`
is per-clone local config so a clone that never ran `mix setup` has no local gate, and
the `REVIEW.signoff` check proves only that a hash was recorded — it cannot prove a
review happened. Enforcing section 0 for real requires branch protection with required
reviewers on the remote, which is not yet configured. Do NOT attempt to bypass
the gate. NEVER use `git commit --no-verify`, `git -C`, `git stash` to dodge checks, or
quiet flags to hide failures. If a gate fails, fix the cause and report the failure honestly.

## 5. Findings need proof (see FINDINGS.md template)
Every bug claim, review comment, or "fixed" assertion cites: exact file path, line
number(s), observed vs expected behavior, and the verification command + its output.
No unverified claims. "I think" / "should work" is not a finding.

## 6. Slice structure & naming
docs/slices/NN-kebab-name/         NN is zero-padded, monotonic (01, 02, ...)
  PLAN.md        # scope contract, written & approved before code
  FINDINGS.md    # evidence log with file:line citations + verification output
  REVIEW.md      # reviewer reports (correctness/security/otp/tests) + verdict
  REVIEW.signoff # sha256 of the reviewed staged diff; consumed by .githooks/pre-commit
One slice = one coherent, reviewable change. If a slice grows past ~10 files or mixes
concerns, split it. Update HANDOFF.md at the end of every slice and before any /compact.

## 7. Commits
- Branch: slice/NN-kebab-name
- Message first line: "NN-kebab-name: <imperative summary>"
- Body: what changed, which acceptance criteria are met, link to FINDINGS.md evidence.
- The commit gate blocks commits whose message has no NN- slice reference.

## 8. Orchestrator vs subagents — who does what
YOU (the main session / orchestrator) MAY:
  - read/plan, write the PLAN, implement code inside the approved slice scope, run gates,
    write FINDINGS with evidence, update HANDOFF, drive git.
YOU MUST DELEGATE (never self-certify):
  - the review. Spawn the independent reviewer subagents via /review (or by name). You do
    NOT get to declare your own diff correct/secure. Reviewers run read-only on the diff.
Reviewers MUST NOT edit code. If a reviewer wants a change, it reports a finding; you fix
it in a new commit within the same slice, then re-review.

## 9. Scope discipline (anti-scope-creep)
Stay inside the current slice's PLAN "In scope". If you discover new work, STOP, log it in
BACKLOG.md and/or open a new slice; do not silently expand. Refactors unrelated to the
slice are out of scope by default.

## 10. Safety for this repo specifically
- Never commit secrets, .env, capture files, PLTs, or real telemetry. Before commit run:
  `git ls-files | grep -Ei '(^|/)\.env$|\.(key|pem|pcap|pcapng|p12)$'` — expect empty.
  (The earlier unanchored pattern always matched `hacktui_core/.../envelope.ex` on the
  substring "env", so the gate could never pass and would have been learned as noise.)
- Sensor code shells out to tshark/dumpcap: treat all external command construction and
  all ingested telemetry (journald, network flows) as untrusted input.
- The MCP server (hacktui_agent) is an external attack surface: review tool inputs,
  auth/authorization, and privacy masking on every change that touches it.

## Reference docs (read before relevant work)
@ARCHITECTURE.md
@THREAT_MODEL.md
@AGENT_SECURITY_MODEL.md
@DEVELOPMENT.md
