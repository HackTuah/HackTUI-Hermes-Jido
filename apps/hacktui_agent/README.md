# hacktui_agent

Purpose:
- Agent integration boundary for MCP, Hermes-facing tools, and future Jido orchestration.

Responsibilities:
- tool surface definition
- agent role catalog
- transcript and run boundary placement
- disabled-by-default agent runtime

Depends on:
- `hacktui_core`
- `hacktui_hub`

Testing:
- agent role and enablement tests now
- future MCP contract and tool boundary tests here

Must not depend on:
- direct destructive execution
- durable alert or case source of truth
- Slack-specific delivery details
