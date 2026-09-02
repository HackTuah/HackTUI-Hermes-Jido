# Documentation index

Start with the root [`README.md`](../README.md). This directory holds operational
reference for running and integrating with HackTUI.

HackTUI is a research prototype. [`not_production_ready.md`](not_production_ready.md)
is the honest statement of what is and is not qualified — read it before drawing
conclusions from anything else here.

## Design and scope (repository root)

| Document | What it covers |
|---|---|
| [`ARCHITECTURE.md`](../ARCHITECTURE.md) | Umbrella layout and where responsibilities sit |
| [`PROJECT_BRIEF.md`](../PROJECT_BRIEF.md) | What the system is for, and what is explicitly out of scope |
| [`THREAT_MODEL.md`](../THREAT_MODEL.md) | Trust boundaries and the risks they are meant to address |
| [`AGENT_SECURITY_MODEL.md`](../AGENT_SECURITY_MODEL.md) | Constraints intended for the agent boundary |
| [`PURPLE_TEAM_MODEL.md`](../PURPLE_TEAM_MODEL.md) | The validation loop the platform is built around |
| [`REPLAY_ENGINE.md`](../REPLAY_ENGINE.md) | Deterministic replay, and what remains an architecture goal |
| [`DECISIONS.md`](../DECISIONS.md) | Decisions taken and why |
| [`residuals.md`](residuals.md) | Known gaps deliberately not closed, with the evidence that made them acceptable |
| [`ROADMAP.md`](../ROADMAP.md) | Direction, distinguished from implemented capability |

## Running it

| Document | What it covers |
|---|---|
| [`operator_boot_runbook.md`](operator_boot_runbook.md) | Bringing the system up |
| [`runtime_modes_matrix.md`](runtime_modes_matrix.md) | Safe-by-default vs DB-backed modes |
| [`failure_modes_and_recovery.md`](failure_modes_and_recovery.md) | What breaks and what to do |
| [`umbrella_layout.md`](umbrella_layout.md) | App boundaries and dependency rules |

## Integrating with it

| Document | What it covers |
|---|---|
| [`mcp_stdio_quickstart.md`](mcp_stdio_quickstart.md) | Connecting an MCP client over stdio |
| [`mcp.md`](mcp.md) | MCP server detail and tool catalogue |
| [`mcp-client-config.example.json`](mcp-client-config.example.json) | Example client configuration |
| [`jido_operating_model.md`](jido_operating_model.md) | How the Jido agent boundary is organised |

## Demonstrations

| Document | What it covers |
|---|---|
| [`demo_runbook.md`](demo_runbook.md) | Running the bounded local demo |
| [`case_1_demo_runbook.md`](case_1_demo_runbook.md) | The case-1 investigation walkthrough |
| [`demo_terminal_launcher.md`](demo_terminal_launcher.md) | Driving the demo from a terminal |

These three overlap substantially and are candidates for consolidation.

## Contributing

[`CONTRIBUTING.md`](../CONTRIBUTING.md) and [`DEVELOPMENT.md`](../DEVELOPMENT.md).
Run `mix setup` after cloning — it fetches dependencies and installs the git hooks that
enforce the quality gates.
