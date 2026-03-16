# hacktui_sensor

Purpose:
- Sensor-side runtime for collectors, local buffering, and forwarding.

Responsibilities:
- host and network collection boundaries
- normalization into shared observation envelopes
- local health and bounded concurrency for collectors

Depends on:
- `hacktui_core`

Testing:
- collector boundary tests
- parser and buffering tests
- forwarding contract tests

Must not depend on:
- detection and alert policy
- casework and approvals
- Slack or Hermes integrations
