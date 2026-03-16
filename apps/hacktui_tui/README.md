# hacktui_tui

Purpose:
- Terminal-first operator experience.

Responsibilities:
- workflow areas and presentation boundaries
- keyboard and command mapping
- future ExRatatui rendering integration

Depends on:
- `hacktui_core`
- `hacktui_hub`

Testing:
- workflow mapping tests now
- future view-model and interaction tests here

Must not depend on:
- Slack-specific code
- Hermes-specific code
- direct persistence writes that bypass the hub
