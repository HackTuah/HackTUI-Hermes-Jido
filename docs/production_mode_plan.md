# HackTUI Production Mode Plan

> Status: foundation slice started. This repo is no longer treated as a demo-only target for planning purposes, but it is not yet honestly production-ready until every acceptance gate below is met.

Goal
- Convert the current umbrella from a bounded local demo into an operational purple-team platform with explicit production gates, secure defaults, verified recovery paths, and auditable runtime behavior.

Phase 0: Production guardrails (current slice)
- Fail fast in `prod` when store persistence is disabled.
- Fail fast in `prod` when DB settings still use demo defaults or qualification DB names.
- Expose production-readiness blockers in store health output.
- Add regression tests for the production config validator and health reporting.

Acceptance criteria
- `MIX_ENV=prod` refuses to boot with `HACKTUI_START_REPO=false`.
- `MIX_ENV=prod` refuses to boot with default DB user/password/host or `hacktui_qualification_test`.
- Health output clearly surfaces configuration blockers instead of silently appearing healthy.
- Regression tests cover valid and invalid production store configurations.

Phase 1: Release hardening
- Build a real OTP release path with environment contracts, release runbooks, and startup probes.
- Add config validation for collab and agent backends so disabled or malformed production paths fail loudly.
- Add release smoke tests for `mix release`, boot, stop, restart, and degraded dependency scenarios.

Acceptance criteria
- Release artifacts boot from a clean host with documented env only.
- Misconfigured providers/backends fail during boot, not after runtime drift.
- Restart and dependency-loss behavior is covered by automated smoke tests.

Phase 2: Service perimeter and control plane
- Add authenticated and authorized operational interfaces for health, status, replay control, approvals, and ingest.
- Add structured logging, telemetry, metrics export, and alert thresholds.
- Add operator-safe admin commands and immutable audit trails for approvals, replays, and escalations.

Acceptance criteria
- Every operational action is authenticated, authorized, and audited.
- Metrics and logs support alerting, SLO review, and forensic reconstruction.
- No unauthenticated mutation path exists.

Phase 3: Data durability and migration discipline
- Formalize production Postgres migrations, backup/restore drills, retention rules, and rollback playbooks.
- Add data integrity checks around investigations, alerts, approvals, and replay evidence.
- Add restore qualification tests against realistic production-like snapshots.

Acceptance criteria
- Backup and restore are automated and tested.
- Migration rollback and forward-only policies are documented and enforced.
- Evidence objects survive restart, replay, and restore flows intact.

Phase 4: Multi-operator purple-team workflows
- Replace single-user/demo workflows with authenticated operator sessions, approvals, queues, and concurrency controls.
- Add role separation for analyst, reviewer, and administrator paths.
- Add conflict-safe coordination for approval and replay actions.

Acceptance criteria
- Concurrent operators cannot corrupt workflow state.
- Role boundaries are enforced in code and tests.
- Reviewer approvals and overrides are audit-complete.

Phase 5: Deployment and operations readiness
- Add production deployment manifests, secret handling guidance, capacity sizing, and on-call runbooks.
- Verify rolling upgrade behavior, node crash recovery, and dependency outage response.
- Establish explicit production readiness review with objective exit criteria.

Acceptance criteria
- A fresh operator can deploy from runbook without tribal knowledge.
- Rolling upgrade and crash recovery have automated verification.
- Readiness review closes every blocker previously tracked in `docs/not_production_ready.md`.

Immediate execution order
1. Land the production config guardrails and health surfacing. Done in this slice.
2. Add release boot validation for agent/collab production env contracts.
3. Build authenticated service interfaces and audit logging.
4. Harden migrations, backup/restore, and recovery drills.
5. Complete operator workflow, deployment, and readiness qualification.

Non-goals for this slice
- Slack transport hardening.
- Full external control plane/API design.
- Final claim of production readiness.
