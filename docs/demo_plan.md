# Demo Plan

Status: concise demo-critical implementation plan.

Goal
Deliver a working, locally runnable demo path for a seeded `case-1` that shows:
- DB-backed runtime
- bounded Jido investigation flow
- visible terminal presentation
- Hermes-local summary and skill artifact generation
- one safe simulated approval path
- optional Slack-facing preview output

## Exact flow

1. Start in DB-backed mode against the current-schema local database.
2. Seed deterministic demo data for `case-1` if missing.
3. Trigger the bounded investigation flow from a reliable local command:
   - `mix demo.investigate case-1`
4. The flow loads normalized investigation context from the hub/store layer.
5. The existing bounded Jido investigation flow runs visibly.
6. A terminal view prints:
   - case id
   - investigation status
   - matched alert ids
   - shared indicators
   - summary
   - recommendation
   - health snapshot
7. A simulated approval-required action is created and clearly labeled simulated.
8. Hermes-local deterministic artifacts are saved:
   - `demo_artifacts/case-1-summary.md`
   - `demo_artifacts/case-1-skill.md`
9. A follow-up command can approve the simulated action:
   - `mix demo.approve case-1`

## Exact modules to touch

Likely modules to add or change:
- `apps/hacktui_agent/lib/hacktui_agent/investigation_flow.ex`
- `apps/hacktui_hub/lib/hacktui_hub/query_service.ex`
- `apps/hacktui_store/lib/hacktui_store/read_models.ex`
- `apps/hacktui_store/lib/hacktui_store/schema/*.ex` only if schema truth truly requires it
- `apps/hacktui_store/lib/hacktui_store/demo_seed.ex`
- `apps/hacktui_hub/lib/hacktui_hub/demo/*.ex`
- `apps/hacktui_tui/lib/hacktui_tui/demo_terminal_view.ex`
- `apps/hacktui_agent/lib/hacktui_agent/hermes_local/*.ex`
- `apps/hacktui_hub/lib/mix/tasks/demo.investigate.ex`
- `apps/hacktui_hub/lib/mix/tasks/demo.approve.ex`
- optional: `apps/hacktui_hub/lib/mix/tasks/demo.view.ex`

## Exact seeded demo data needed

For `case-1`:
- one case record
- at least two related alerts with shared indicators
- timeline entries with matching indicators in metadata
- one deterministic recommendation target for a simulated action
- one actor identity string for audit and approval persistence

Minimum indicator set:
- `malicious.example`
- `10.0.0.4`

## Acceptance criteria

Phase 1 acceptance:
- root cause of the `alerts.alert_id` mismatch is identified precisely
- `HacktuiAgent.InvestigationFlow.run("case-1")` works in a real local DB-backed runtime
- `HacktuiAgent.InvestigationFlow.run("case-1", [])` works
- `HacktuiAgent.InvestigationFlow.run("case-1", %{})` works

Phase 2/3 acceptance:
- deterministic demo seed produces stable visible results
- investigation result includes matched alert ids and shared indicators
- Hermes-local artifacts are generated deterministically
- one simulated approval path exists and is explicitly labeled simulated

Phase 4/5 acceptance:
- `mix demo.investigate case-1` is the reliable local demo entry point
- there is a clear terminal/TUI launch path for demo visibility
- exact startup order, env vars, and fallback commands are documented
