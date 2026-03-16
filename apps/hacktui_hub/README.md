# hacktui_hub

Purpose:
- Authoritative hub runtime and workflow orchestrator.

Responsibilities:
- supervision and orchestration
- shared command/query entrypoints for the runtime
- ingest, detection, casework, response, policy, and audit coordination

Depends on:
- `hacktui_core`
- `hacktui_store`

Testing:
- supervision smoke tests now
- future orchestration and contract tests here

Must not depend on:
- Slack-specific transport details
- Hermes-specific clients
- raw collector integrations
- direct TUI rendering as a domain source of truth
