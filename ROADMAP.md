# Roadmap (Updated)

## Now

- complete the distributed **hub + sensor** architecture
- make hub nodes the authoritative ingest, detection, casework, approval, and query plane
- make sensor nodes perform real local collection and forward normalized observations to hub ingest
- finalize BEAM-native cluster discovery using `:pg`
- implement reliable sensor-to-hub forwarding with bounded retry, failover, and provenance metadata
- harden observation fingerprinting and idempotent ingest so retries do not duplicate alerts
- make real collector paths work for:
  - packet capture
  - journald events
  - process signals
- ensure live observations flow through the existing command/event/store path
- make the TUI show real observations, alerts, cases, approvals, and cluster health
- keep Jido investigation flows working against real case data
- keep Hermes artifact generation working from real investigation findings
- verify the live distributed path end-to-end:
  - sensor sees real activity
  - hub accepts observations
  - detection produces alerts
  - query/TUI reflects the state
  - failover works when one hub dies

## Next

- add richer purple-team exercise modeling through `PurpleExercise` / `PurpleService`
- connect replay, exercise execution, and live detection into a shared validation loop
- improve ATT&CK-oriented exercise metadata and coverage tracking
- extend Jido workflows beyond basic investigation into richer multi-step case reasoning
- improve Hermes skill and artifact generation from investigation results
- strengthen cluster/runtime health visibility for operators
- tighten hub / sensor / agent / store boundaries around live distributed operation
- improve TUI usability while keeping it honest and operator-first
- expand qualification and integration coverage for distributed cluster behavior

## Later

- multiple hub nodes in more production-like clustered deployments
- broader sensor coverage and more advanced collectors
- proof-carrying alerts and investigations
- replay-driven regression harnesses for continuous validation
- richer approval and action classes
- collaboration boundaries that remain explicit and auditable
- autonomous but bounded improvement loops driven by replay, investigation, and artifact generation
- continuous purple-team control-plane capabilities with deterministic validation and operator oversight
