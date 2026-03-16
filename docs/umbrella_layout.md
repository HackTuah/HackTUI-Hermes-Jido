# HackTUI umbrella layout proposal

This proposal translates `ARCHITECTURE.md` into a pragmatic Elixir umbrella split.

Important context:
- `ARCHITECTURE.md` recommends staying in a single app until boundaries stabilize.
- The current refactor requirement explicitly prefers an umbrella unless there is a strong reason not to.
- To reconcile those two, the umbrella should stay coarse-grained. Do not make one child app per bounded context yet.

## Recommendation: 7 child apps

```text
apps/
├── hacktui_core
├── hacktui_store
├── hacktui_hub
├── hacktui_sensor
├── hacktui_tui
├── hacktui_collab
└── hacktui_agent
```

This gives one pure inner core, one persistence boundary, one hub orchestration app, and four edge/surface apps.

## Why this split

The main architectural pressure in `ARCHITECTURE.md` is not "many deployables". It is:
- separate durable domain logic from adapters
- keep Hermes and Slack non-authoritative
- keep the hub usable even if external integrations fail
- put side effects and concurrency behind explicit boundaries
- keep TUI, Slack, MCP, and sensors on one shared command/query/audit model

A coarse umbrella with these apps enforces those rules without prematurely fragmenting every bounded context.

## App-by-app responsibilities

### 1. `hacktui_core`
Purpose:
- Pure domain model and contracts.
- The place for command structs, query DTOs, domain event structs, policy/value objects, reducers/state transition logic, and behaviour contracts for adapters.

Owns:
- Canonical observation envelope types and validation rules that can stay pure
- Detection rule evaluation and alert state transition rules
- Case, evidence, response, approval, policy, actor, and audit domain invariants
- Collaboration and agent domain records at the model level, not the Slack/Hermes transport level
- Port behaviours for persistence, notifications, transport, enrichment, execution, and transcript sinks

Does not own:
- Ecto schemas and migrations
- GenServers, Tasks, network clients, Port drivers, Slack SDK calls, Hermes/MCP clients
- ExRatatui rendering

Notes:
- This should be the most testable app.
- Prefer plain structs and pure functions.
- If a function needs time, randomness, IO, or external identity lookup, take it as an argument or hide it behind a behaviour.

### 2. `hacktui_store`
Purpose:
- PostgreSQL and durable storage boundary.
- Ecto repo, migrations, schemas, projection persistence, and adapter implementations for repository behaviours declared in `hacktui_core`.

Owns:
- `Repo`
- Ecto schemas and changesets
- migrations
- event/projection persistence adapters
- query adapters for read models backed by Postgres

Does not own:
- alert/case/policy business rules
- Slack or Hermes clients
- TUI state

Notes:
- Keep Ecto here so domain logic in `hacktui_core` is not forced into changesets.
- A useful rule: Ecto structs do not cross inward as domain truth.

### 3. `hacktui_hub`
Purpose:
- Hub-side application services and OTP orchestration.
- The authoritative workflow runtime for ingest, detection, casework, evidence, response governance, policy, audit, read-model updates, and hub health.

Owns:
- command handlers / application services
- workflow orchestration across bounded contexts
- supervision trees for hub processes
- event dispatch inside the BEAM runtime
- read-model/projector orchestration
- public APIs used by TUI, Slack, MCP, and agents

Does not own:
- raw collector integration
- Slack transport details
- Hermes/MCP transport details
- direct UI rendering

Notes:
- This is where concurrency belongs, not in `hacktui_core`.
- Use `hacktui_core` for decisions and `hacktui_store` for persistence.
- If something talks to Slack or Hermes directly, it likely does not belong here.

### 4. `hacktui_sensor`
Purpose:
- Sensor-side runtime.
- Local collection, local normalization, local buffering, sensor health, and forwarding to the hub.

Owns:
- collector wrappers around tcpdump/journald/other host sources
- parser isolation and normalization into the canonical observation envelope
- local bounded buffer / retry / backpressure policy
- sensor health and capability reporting
- forwarding client to the hub ingest interface

Does not own:
- detection policy
- casework
- approvals
- Slack or Hermes logic

Notes:
- This app should depend on shared envelope contracts in `hacktui_core`, not on hub internals.
- Treat privileged collectors and OS integration as adapters.

### 5. `hacktui_tui`
Purpose:
- Operator experience surface.
- ExRatatui rendering, keyboard workflows, command palette, and view-model composition.

Owns:
- terminal rendering
- input mapping to shared commands
- presentation/view-model logic
- TUI-specific supervisors/processes

Does not own:
- durable alert/case/action truth
- policy decisions
- direct database writes that bypass hub services

Notes:
- The TUI should call hub APIs and consume read models.
- It should never become a second domain engine.

### 6. `hacktui_collab`
Purpose:
- Secondary collaboration surface adapters, initially Slack.
- Inbound/outbound request handling, Slack signature validation, formatting, delivery tracking adapters, and transcript plumbing.

Owns:
- Slack-specific clients and request validation
- formatting from domain read models into Slack payloads
- inbound Slack command/interaction adapters
- delivery retries and Slack transport concerns

Does not own:
- alert/case/action source of truth
- policy bypasses
- direct execution authority

Notes:
- Collaboration domain records can still be defined in `hacktui_core` and orchestrated by `hacktui_hub`.
- This app should be the only app that knows Slack wire formats or Slack libraries.

### 7. `hacktui_agent`
Purpose:
- Agent operations edge app.
- MCP server/tool gateway, Hermes-facing adapters, Jido/model integration, run transcript adapters, and proposal submission adapters.

Owns:
- MCP protocol/server surface
- typed tool exposure to Hermes
- agent run supervision/orchestration adapters
- transcript capture adapters
- model/backend integration concerns

Does not own:
- durable alert/case/action truth
- direct destructive authority
- policy bypasses

Notes:
- This app should be the only place that knows Hermes/MCP/model-client specifics.
- It may propose actions, never execute them directly.

## Mapping from architecture bounded contexts

```text
Sensor Collection            -> hacktui_sensor + hacktui_core contracts
Ingest & Normalization       -> hacktui_core domain + hacktui_hub orchestration + hacktui_store persistence
Detection & Alerting         -> hacktui_core domain + hacktui_hub orchestration + hacktui_store persistence
Casework & Investigation     -> hacktui_core domain + hacktui_hub orchestration + hacktui_store persistence
Evidence & Artifacts         -> hacktui_core domain + hacktui_hub orchestration + hacktui_store persistence
Response Governance          -> hacktui_core domain + hacktui_hub orchestration + hacktui_store persistence
Policy/Identity/Audit        -> hacktui_core domain + hacktui_hub orchestration + hacktui_store persistence
Collaboration                -> hacktui_core domain model + hacktui_hub services + hacktui_collab Slack adapter
Operator Experience          -> hacktui_tui
Agent Operations             -> hacktui_core domain model + hacktui_hub services + hacktui_agent edge adapter
Platform Operations          -> initially split between hacktui_hub and hacktui_store; do not make a dedicated app yet
```

## Dependency direction

Recommended compile-time direction:

```text
hacktui_core
├── no internal app deps

hacktui_store
└── depends on: hacktui_core

hacktui_hub
└── depends on: hacktui_core, hacktui_store

hacktui_sensor
└── depends on: hacktui_core

hacktui_tui
└── depends on: hacktui_core, hacktui_hub

hacktui_collab
└── depends on: hacktui_core, hacktui_hub

hacktui_agent
└── depends on: hacktui_core, hacktui_hub
```

Practical rule:
- dependencies point inward toward `hacktui_core`
- side-effect apps never become dependencies of core workflow apps
- `hacktui_hub` is allowed to depend on storage, but storage must not depend on hub
- `hacktui_tui`, `hacktui_collab`, and `hacktui_agent` may depend on hub APIs, but hub must not depend on them

## What should never directly depend on Slack or Hermes

These apps should never directly depend on Slack clients, Hermes clients, or MCP/model SDKs:
- `hacktui_core`
- `hacktui_store`
- `hacktui_hub`
- `hacktui_sensor`
- `hacktui_tui`

Only these edge apps should know those integrations:
- `hacktui_collab` knows Slack
- `hacktui_agent` knows Hermes/MCP/Jido/model backends

That preserves the architecture rule that Slack and Hermes are secondary surfaces, not the runtime source of truth.

## Initial supervision tree suggestions

### `hacktui_core`
- No `Application` module initially.
- Pure library app only.

### `hacktui_store`
Start:
- `Hacktui.Store.Repo`
- optional projector/query cache supervisor if needed later

### `hacktui_hub`
Start coarse supervisors only:
- `Hacktui.Hub.CommandSupervisor`
- `Hacktui.Hub.EventSupervisor`
- `Hacktui.Hub.IngestSupervisor`
- `Hacktui.Hub.ReadModelSupervisor`
- `Hacktui.Hub.HealthSupervisor`

The point is not to fully implement workflows yet, only to reserve explicit places for them.

### `hacktui_sensor`
Start:
- `Hacktui.Sensor.BufferSupervisor`
- `Hacktui.Sensor.CollectorSupervisor`
- `Hacktui.Sensor.Forwarder`
- `Hacktui.Sensor.HealthReporter`

### `hacktui_tui`
Start:
- `Hacktui.TUI.SessionSupervisor`
- `Hacktui.TUI.DashboardSupervisor`

Gate startup by config so hub releases can run headless.

### `hacktui_collab`
Start only when enabled:
- `Hacktui.Collab.OutboxSupervisor`
- `Hacktui.Collab.DeliverySupervisor`
- Slack inbound surface if/when added

### `hacktui_agent`
Start only when enabled:
- `Hacktui.Agent.RunSupervisor`
- `Hacktui.Agent.ToolGateway`
- MCP server/process if enabled

## Testing split

### Best isolated tests
- `hacktui_core`: unit tests and property tests for invariants, reducers, transitions, classification, and rule evaluation
- `hacktui_sensor`: parser/normalizer/buffer tests with fake forwarders
- `hacktui_tui`: view-model and input-to-command mapping tests with fake hub APIs

### Adapter tests
- `hacktui_store`: Ecto/integration tests against Postgres or sandbox
- `hacktui_collab`: Slack signature, formatting, idempotency, and retry tests with fake hub services
- `hacktui_agent`: MCP tool contract tests, transcript handling, and proposal path tests with fake hub services/model adapters

### Orchestration tests
- `hacktui_hub`: command handler and workflow tests with in-memory fakes for store and outbound adapters

## Release shape

This split also maps cleanly to deployment roles.

Hub release:
- `hacktui_core`
- `hacktui_store`
- `hacktui_hub`
- optional `hacktui_tui`
- optional `hacktui_collab`
- optional `hacktui_agent`

Sensor release:
- `hacktui_core`
- `hacktui_sensor`

That matches the architecture model of one authoritative hub and optional remote sensors.

## Why not split further right now

Avoid a separate child app per bounded context for the first scaffold.

Reasons:
- too many apps too early will create dependency churn before contracts settle
- the pure-vs-side-effect boundary matters more right now than the exact count of bounded-context apps
- many contexts still share the same hub runtime and persistence boundary for now
- this layout is enough to prove isolation rules, optional integrations, and role-specific releases

## Optional later splits

Only split further after real pressure appears.

Likely future candidates:
- split `hacktui_store` into workflow store vs evidence store if artifact storage diverges
- split `hacktui_hub` into `hacktui_workflows` and `hacktui_ops` if platform/runtime operations become large
- split `hacktui_collab` if non-Slack collaboration surfaces become real
- split `hacktui_agent` if MCP and internal agent orchestration diverge materially

## Scaffold guidance for per-app READMEs

Each child app README should state:
- purpose
- owns
- does not own
- public APIs
- inbound dependencies
- outbound adapter dependencies
- test strategy
- enable/disable behavior in releases

That will make the later explanation of "why this app exists" very easy and consistent.
