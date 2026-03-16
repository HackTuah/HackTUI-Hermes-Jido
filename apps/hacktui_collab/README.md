# hacktui_collab

Purpose:
- Collaboration and notification integrations.

Responsibilities:
- Slack-specific intake and delivery adapters
- outbound notification formatting boundaries
- transcript and delivery plumbing
- disabled-by-default collaboration runtime

Depends on:
- `hacktui_core`
- `hacktui_hub`

Testing:
- provider catalog tests now
- future Slack contract, idempotency, and formatting tests here

Must not depend on:
- source-of-truth case state
- approval policy bypasses
- Hermes integration concerns
