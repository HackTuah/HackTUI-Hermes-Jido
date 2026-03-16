# HackTUI Architecture

HackTUI is a local-first, terminal-first security platform built in Elixir on the BEAM. The current repo contains a bounded operational foundation that can grow from blue-team workflows into a replay-driven purple-team control plane.

## Architecture principles

- the BEAM is the durable runtime for concurrency, supervision, and fault isolation
- the umbrella boundaries are explicit and remain the primary architecture
- durable records, auditability, and deterministic behavior matter more than flashy automation
- Jido is used for bounded workflow orchestration, not agent theater
- Hermes is an advisory and improvement layer, not an unchecked source of authority

## Major system layers

### Sensors

Sensor responsibilities:
- collect or derive observations from local or future external telemetry sources
- normalize inputs into stable domain-facing envelopes
- support deterministic replay inputs as a first-class direction
- remain least-privilege and failure-isolated under supervision

Current and planned direction:
- current repo includes a `hacktui_sensor` boundary
- replay-oriented sensor inputs are a core planned direction for validation and regression work
- sensor breadth should expand only when normalization, auditability, and replay remain intact

### Hub control plane

`hacktui_hub` is the control plane boundary.

Responsibilities:
- coordinate ingest, orchestration, query access, and runtime health
- own read-model style views used by demo, terminal, and future collaboration surfaces
- enforce safe runtime gating and truthful control-plane behavior
- provide the central command/query boundary used by other surfaces

The hub should remain the authoritative operational boundary rather than letting terminal, Slack, or agent layers invent parallel truths.

### Store

`hacktui_store` is the durable persistence boundary.

Responsibilities:
- persist alerts, investigations, approvals, and audit-relevant records
- host Ecto schemas, repo wiring, migrations, and deterministic seed helpers
- support reproducible local demo and qualification paths
- provide a durable substrate for future replay fixtures, evidence references, and regression artifacts

The store is where system truth should live. External delivery surfaces and agents consume and contribute through bounded interfaces, not direct hidden state.

### Terminal UI

`hacktui_tui` is the primary operator surface.

Responsibilities:
- present bounded, honest terminal-visible state
- show investigation and approval information without overstating system maturity
- remain usable in local operator workflows and future live SOC views
- expose operational clarity rather than dashboard theater

The terminal surface is primary because it aligns with local-first operation, observability, and explicit operator control.

### Agent layer

`hacktui_agent` hosts bounded investigation and reporting workflows.

Responsibilities:
- run bounded Jido-backed investigation flows
- produce structured summaries and local artifacts where appropriate
- support future advisory workflows for improvement, replay analysis, and report drafting
- preserve auditability and clear boundaries between proposals and effects

Jido role:
- bounded orchestration
- explicit directives and workflow state transitions
- inspectable side-effect boundaries

Hermes role:
- advisory planning, synthesis, and continuous improvement support
- report drafting, candidate detection ideas, and structured assistance
- never silent or unchecked authority over high-impact actions

## Umbrella apps

- `hacktui_core`: domain types, actor refs, commands, events, aggregates, and shared concepts
- `hacktui_store`: Ecto repo, schemas, migrations, deterministic seeds, and durable records
- `hacktui_hub`: runtime orchestration, queries, health/status, and demo coordination
- `hacktui_sensor`: sensor and replay-oriented ingest boundary
- `hacktui_tui`: terminal presentation layer
- `hacktui_collab`: optional collaboration/provider boundary
- `hacktui_agent`: bounded investigation, summarization, and advisory workflow boundary
- `hacktui`: umbrella entrypoint and mix task layer

## Current bounded demo path

1. local DB mode is explicitly enabled
2. deterministic demo data is seeded through the store boundary
3. an investigation flow runs through the agent boundary
4. summary output is produced for bounded local visibility
5. the hub/runtime path creates a simulated approval request
6. demo mix tasks and terminal presentation make the workflow visible

This path is intentionally narrow. It is the current truthful foundation, not the final platform shape.

## Target control-plane shape

Planned architectural direction:
- sensors and replay feeds submit observations into the same durable domain path
- the hub coordinates deterministic detection, investigation, approvals, and operator queries
- the store persists evidence, cases, audits, and future replay artifacts
- the terminal UI remains the primary interface for operators
- collaboration surfaces remain secondary and audited
- the agent layer proposes and assists, but does not become the system of record

## Purple-team expansion path

The purple-team end state builds on the existing architecture rather than replacing it:
- adversary simulation and deterministic replay feed the same ingest path
- detections are validated against expected outcomes
- investigations produce evidence-backed summaries
- misses become actionable backlog items and regression fixtures
- collaboration and advisory agents operate on durable records and audit trails

## Guardrails

- prefer repo truth over conversational assumptions
- keep runtime defaults safe and explicit
- keep terminal output bounded and honest
- treat replay and simulation as explicit workflows, not hidden magic
- do not document planned capabilities as already verified production features