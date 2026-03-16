# Backlog

This backlog is a phased roadmap. Items listed as future phases are planned direction, not implemented capability.

## Current work

- stabilize the bounded local demo path
- keep investigation, approval, and terminal output deterministic and honest
- preserve safe defaults and avoid parallel implementation paths

## Phase 1: Deterministic replay and regression harness

Planned outcomes:
- deterministic replay inputs for known scenarios
- repeatable expected outputs for alerts, investigations, and approvals
- regression tests that catch detection or investigation drift
- durable fixture and artifact handling for local validation

## Phase 2: Live terminal SOC interface

Planned outcomes:
- richer terminal queue, case, and audit views
- honest runtime health and status visibility
- operator workflows that remain bounded and inspectable
- no claim of a complete production SOC console until verified

## Phase 3: Proof-carrying alerts and investigations

Planned outcomes:
- alerts tied to evidence references and explanation structures
- investigation summaries that show why a conclusion was reached
- durable linkage between detections, evidence, approvals, and outputs
- reduced analyst ambiguity during review

## Phase 4: Slack collaboration and audited delivery

Planned outcomes:
- outbound collaboration as a secondary interface
- durable delivery records and failure visibility
- explicit approval and posting boundaries
- fail-closed provider behavior when not configured

## Phase 5: Purple-team validation loop

Planned outcomes:
- adversary simulation and replay as routine validation inputs
- ATT&CK-aligned exercise metadata and coverage tracking
- expected-vs-observed comparison workflows
- continuous improvement from misses, regressions, and analyst feedback

## Phase 6: Bounded agent assistance

Planned outcomes:
- advisory Hermes workflows for planning, summarization, and improvement proposals
- explicit tool scopes and approval gates
- auditability for agent runs and outputs
- no unchecked autonomous response claims

## Working rules

- build on the existing umbrella boundaries and demo path
- document current capability separately from planned direction
- no fake implementations
- no placeholder security claims
- production-safe defaults only
- prefer deterministic local output over cleverness