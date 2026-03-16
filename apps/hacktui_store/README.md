# hacktui_store

Purpose:
- Persistence boundary for durable security records.

Responsibilities:
- repository and schema home
- durable record families and storage contracts
- future Ecto/PostgreSQL integration

Depends on:
- `hacktui_core`

Testing:
- storage contract tests now
- future database integration tests here

Must not depend on:
- Slack or Hermes integrations
- TUI rendering
- alert and case policy decisions
