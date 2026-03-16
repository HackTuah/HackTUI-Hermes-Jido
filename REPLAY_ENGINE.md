# Replay Engine

HackTUI is intended to become replay-first.

## Purpose

A deterministic replay engine lets the platform feed known scenarios back through bounded ingest, detection, and investigation paths so behavior can be validated repeatedly.

## Why replay matters

Replay matters because security workflows degrade when teams cannot answer:
- what exactly was tested?
- what output was expected?
- what changed after a rule or workflow update?
- did we improve detection quality or only move the noise around?

Replay turns those questions into engineering problems with testable answers.

## Planned architecture

Replay should fit the existing umbrella boundaries:
- `hacktui_sensor` accepts replay inputs as a first-class source
- `hacktui_hub` coordinates execution and comparison
- `hacktui_store` persists fixtures, outcomes, and audit-relevant artifacts
- `hacktui_core` owns deterministic domain behavior and comparison logic
- `hacktui_tui` shows bounded expected-vs-observed output
- `hacktui_agent` can summarize replay outcomes and suggest improvements

## Design goals

- deterministic inputs
- deterministic or explicitly bounded outputs
- repeatable comparisons across versions
- durable evidence and audit records
- safe local execution by default

## Operational model

A replay workflow should look like this:
1. load a known scenario or fixture set
2. run it through the normal bounded ingest path
3. persist alerts, investigation outputs, and approvals or simulated requests
4. compare results with expected outcomes
5. report deltas clearly
6. convert accepted improvements into regression fixtures

## Status note

Replay-first validation is a core planned direction. It should be treated as a strategic architecture goal unless and until the repo contains verified replay commands, tests, and outputs that prove the feature end to end.

## Guardrails

- replay should not be confused with live production telemetry
- simulated actions must remain marked simulated
- replay outputs should remain auditable and reviewable
- replay should reduce ambiguity, not introduce hidden test magic