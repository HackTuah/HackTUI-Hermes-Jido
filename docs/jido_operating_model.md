# Jido Operating Model for HackTUI

Status: architecture and implementation guidance.

Principle
- The BEAM runtime remains the durable source of truth.
- Jido is used only where long-lived, signal-driven, multi-step workflows provide clear value.
- Plain detection, policy, and persistence logic remain plain Elixir unless there is a strong orchestration reason to do otherwise.
- No agent theater.

## 1. Subsystem classification table

| Subsystem | App | Classification | Rationale |
| --- | --- | --- | --- |
| Value objects, commands, domain events | `hacktui_core` | plain Elixir module | Pure contracts and data structures are deterministic, easy to test, and do not need processes. |
| Alert lifecycle rules | `hacktui_core` | plain Elixir module | Pure state transitions do not benefit from agent orchestration. |
| Case lifecycle rules | `hacktui_core` | plain Elixir module | Same reason as alert lifecycle; these are core invariants. |
| Aggregates and pure command handlers | `hacktui_core` | plain Elixir module | They should stay side-effect free and reusable from any outer boundary. |
| Ecto schemas and changesets | `hacktui_store` | plain Elixir module | These are persistence shapes, not long-lived workflows. |
| Read-model query builders | `hacktui_store` | plain Elixir module | Query construction is pure and should remain cheap to test. |
| Repo process | `hacktui_store` | OTP worker/process | Ecto Repo is a supervised runtime boundary with connection pooling and retries. |
| PostgreSQL | external | external service/tool | Durable storage should remain outside BEAM. |
| Sensor collectors (tcpdump, journald, eBPF-style tools later) | `hacktui_sensor` | external service/tool | These are privileged or OS-native integrations, not good candidates for Jido. |
| Sensor buffer/forwarding runtime | `hacktui_sensor` | OTP worker/process | Collection, buffering, and retry are long-lived runtime concerns but not agentic workflows. |
| Ingest validation | `hacktui_hub` | plain Elixir module + OTP runtime wrapper | Validation logic is pure; supervision and concurrency stay in OTP. |
| Detection and threshold correlation engine | `hacktui_hub` | plain Elixir module + OTP runtime wrapper | Correlation rules should stay deterministic and observable, not agent-driven. |
| Case and response orchestration | `hacktui_hub` | OTP worker/process | These are long-lived workflow boundaries, but they are authoritative runtime flows, not agent workflows. |
| Policy and audit classification | `hacktui_hub` | plain Elixir module | Authorization and audit decisions must stay deterministic and reviewable. |
| TUI workflow specs | `hacktui_tui` | plain Elixir module | Presentation contracts are static and query-driven. |
| TUI session management | `hacktui_tui` | OTP worker/process | Session lifecycle and rendering are runtime concerns. |
| Slack router and renderer | `hacktui_collab` | plain Elixir module | Routing/formatting are pure and should remain simple. |
| Slack delivery transport | `hacktui_collab` | external service/tool | Slack is an external SaaS boundary. |
| MCP tool catalog and dispatch | `hacktui_agent` | plain Elixir module | Tool routing is a boundary contract, not a stateful workflow by itself. |
| Hermes / model backend | external | external service/tool | Hermes remains external to the durable runtime. |
| Investigation coordinator | `hacktui_agent` | Jido agent | Multi-step investigation flow benefits from explicit state, directives, signal routing, and bounded orchestration. |
| Approval reminder / escalation workflow | planned in `hacktui_agent` | Jido agent | This benefits from scheduling, retries, reminders, and signal-driven escalation. |
| Post-incident review workflow | planned in `hacktui_agent` | Jido agent | This is a long-lived, multi-step workflow with clear state progression and handoff signals. |

## 2. Why Jido is used only in narrow places

Jido is appropriate here only when all of the following are true:
- the workflow is multi-step
- the workflow benefits from explicit state progression
- the workflow emits effects as directives
- the workflow can be driven by signals
- the workflow should remain bounded and reviewable

Jido is not the right tool for:
- pure detection logic
- plain policy decisions
- CRUD-like persistence
- rendering concerns
- external transport adapters

This keeps the system honest:
- detection remains deterministic
- policy remains deterministic
- persistence remains deterministic
- Jido handles orchestration, not truth

## 3. First set of Jido agents to implement

### Implement now
1. `HacktuiAgent.Agents.InvestigationCoordinator`
- Purpose: orchestrate a bounded, multi-step investigation flow after a case is opened or a correlation trigger is raised.
- Why Jido: it has real value from multi-step action sequencing, emitted directives, signal-driven completion, and explicit workflow state.

### Implement next
2. `ApprovalEscalationAgent`
- Purpose: monitor long-lived pending approvals, schedule reminders, and emit escalation signals when SLAs are breached.
- Why Jido: this is fundamentally a scheduling and signal-routing problem.

3. `PostIncidentReviewAgent`
- Purpose: drive the post-incident review workflow from case closure to draft review packet generation.
- Why Jido: it is a long-lived parent-child style workflow with multiple steps and explicit completion states.

## 4. Jido agent definitions

### 4.1 InvestigationCoordinator

Status
- Implemented as the first Jido-powered flow.

Agent module
- `HacktuiAgent.Agents.InvestigationCoordinator`

Signals
- `hacktui.investigation.start`
  - start an investigation using already gathered hub context
- `hacktui.correlation.triggered`
  - start investigation because deterministic correlation crossed a threshold
- `hacktui.investigation.completed`
  - emitted when the flow finishes correlation and report drafting

Actions
- `HacktuiAgent.Actions.Investigation.CorrelateContext`
  - correlate hub-provided alert queue and case timeline context
- `HacktuiAgent.Actions.Investigation.DraftReport`
  - generate a deterministic draft summary from the correlated state
- `HacktuiAgent.Actions.Investigation.EmitCompletion`
  - emit the completion signal as a Jido directive

Directives
- `%Jido.Agent.Directive.Emit{}`
  - used to emit `hacktui.investigation.completed`

State shape
- `status :: :idle | :queued | :correlated | :report_drafted | :completed`
- `case_id :: String.t()`
- `context :: %{alerts: list(map()), timeline: list(map())}`
- `correlation :: %{case_id: String.t(), matched_alert_ids: [String.t()], shared_indicators: [String.t()]}`
- `report_draft :: %{case_id: String.t(), summary: String.t(), matched_alert_ids: [String.t()], shared_indicators: [String.t()]}`

Boundary rule
- The agent does not query the database itself.
- Hub query services gather context first.
- The Jido flow then operates on bounded in-memory context and emits directives.

### 4.2 ApprovalEscalationAgent

Status
- Planned, not implemented yet.

Signals
- `hacktui.approval.pending`
- `hacktui.approval.reminder_due`
- `hacktui.approval.escalated`
- `hacktui.approval.resolved`

Actions
- `LoadApprovalContext`
- `ScheduleReminder`
- `EmitReminder`
- `EmitEscalation`
- `StopOnResolution`

Directives
- `%Jido.Agent.Directive.Schedule{}`
- `%Jido.Agent.Directive.Emit{}`
- `%Jido.Agent.Directive.Stop{}`

State shape
- `action_request_id`
- `status`
- `requested_at`
- `last_reminder_at`
- `reminder_count`
- `escalation_target`

### 4.3 PostIncidentReviewAgent

Status
- Planned, not implemented yet.

Signals
- `hacktui.case.closed`
- `hacktui.review.start`
- `hacktui.review.completed`

Actions
- `GatherReviewContext`
- `DraftLessonsLearned`
- `DraftRunbookChanges`
- `EmitReviewReady`

Directives
- `%Jido.Agent.Directive.Emit{}`
- potentially `%Jido.Agent.Directive.SpawnAgent{}` later if review gets split into child workflows

State shape
- `case_id`
- `review_status`
- `review_context`
- `lessons_learned`
- `draft_updates`

## 5. Updated supervision tree design

```text
HacktuiHub.Application
└── HacktuiHub.Supervisor
    ├── HacktuiStore.Supervisor
    │   ├── TaskSupervisor
    │   └── Repo (optional by config)
    ├── HacktuiHub.Registry
    ├── HacktuiHub.TaskSupervisor
    ├── HacktuiHub.IngestSupervisor
    ├── HacktuiHub.DetectionSupervisor
    ├── HacktuiHub.CaseworkSupervisor
    ├── HacktuiHub.ResponseSupervisor
    ├── HacktuiHub.PolicySupervisor
    ├── HacktuiHub.AuditSupervisor
    ├── HacktuiTui.Supervisor (optional in headless deployments)
    │   ├── SessionSupervisor
    │   └── TaskSupervisor
    ├── HacktuiCollab.Supervisor (optional, disabled by default)
    │   └── TaskSupervisor
    └── HacktuiAgent.Supervisor (optional, disabled by default)
        ├── TaskSupervisor
        └── HacktuiAgent.Jido (only when `:jido` backend enabled)
            ├── Jido.AgentSupervisor
            ├── Jido.Registry
            ├── Jido worker pool / schedulers
            └── Jido instance runtime internals
```

Design intent
- The hub remains authoritative.
- Jido is an optional orchestration layer inside the BEAM runtime, not a separate source of truth.
- Jido agents consume bounded context from hub queries and produce bounded directives or proposals.

## 6. First implemented Jido flow

Implemented modules
- `HacktuiAgent.Jido`
- `HacktuiAgent.Agents.InvestigationCoordinator`
- `HacktuiAgent.Actions.Investigation.CorrelateContext`
- `HacktuiAgent.Actions.Investigation.DraftReport`
- `HacktuiAgent.Actions.Investigation.EmitCompletion`
- `HacktuiAgent.InvestigationFlow`

Execution model
1. Plain hub query services gather bounded case context:
   - alert queue rows
   - case timeline rows
2. `HacktuiAgent.InvestigationFlow.run/2` creates a Jido `InvestigationCoordinator` agent with that context in state.
3. The flow runs a multi-step action sequence:
   - correlate context
   - draft report
   - emit completion signal
4. The final state is returned along with Jido directives.

Why this is the right first Jido flow
- it is multi-step
- it has explicit state progression
- it emits a real directive
- it consumes bounded context from the hub
- it does not pretend LLM reasoning is mandatory for basic value
- it avoids moving deterministic detection logic into an agent

## 7. Explicit non-goals for Jido in HackTUI

Do not use Jido for:
- raw telemetry ingest
- deterministic alert threshold evaluation
- policy enforcement
- audit event generation
- direct Slack transport
- direct Hermes transport
- persistence
- TUI rendering

These remain better served by plain Elixir modules, OTP workers, and external integrations.
