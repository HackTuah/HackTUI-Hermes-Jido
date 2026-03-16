# Runtime Modes Matrix

Status: current verified runtime matrix.

| Mode | Required env/config | Starts Repo | Starts collab runtime | Starts agent runtime | Starts Jido instance | Intended use | Qualification status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Safe no-repo mode | default settings | No | No | No | No | local development, compile/test, architecture work | verified by default suite |
| DB-backed mode | `source .env`, `HACKTUI_START_REPO=true` | Yes | No | No | No | persistence integration and local DB-backed runtime work | verified in controlled local qualification |
| Collaboration-enabled mode | `HACKTUI_COLLAB_PROVIDERS=slack` | Optional | Yes | No | No | exercising collab boundary startup and Slack routing/renderer code | runtime-gated only; not full transport-qualified |
| Agent-enabled mode | `HACKTUI_AGENT_BACKENDS=jido` | Optional | No | Yes | Yes | bounded Jido workflow execution and agent boundary startup | verified for bounded investigation flow |
| DB-backed + hub mode | `source .env`, `HACKTUI_START_REPO=true` | Yes | No | No | No | hub/store round-trip qualification | verified in controlled local qualification |
| DB-backed + agent-enabled mode | `source .env`, `HACKTUI_START_REPO=true`, `HACKTUI_AGENT_BACKENDS=jido` | Yes | No | Yes | Yes | bounded DB-backed agent runtime smoke | verified in controlled local smoke qualification |
| DB-backed + collab mode | `source .env`, `HACKTUI_START_REPO=true`, `HACKTUI_COLLAB_PROVIDERS=slack` | Yes | Yes | No | No | future collaboration qualification | not qualified in this pass |
