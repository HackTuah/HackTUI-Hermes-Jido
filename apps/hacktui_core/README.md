# hacktui_core

Purpose:
- Pure domain kernel for HackTUI.

Responsibilities:
- bounded context catalog
- command classes and lifecycle values
- pure structs, value objects, and transition logic as implementation grows

Depends on:
- no internal apps

Testing:
- isolated unit tests
- pure function and state-transition tests

Must not depend on:
- Slack libraries
- Hermes or MCP clients
- TUI rendering
- Ecto and database adapters
- Port drivers or OS-facing collectors
