# Purple Team Model

HackTUI is moving toward a continuous purple-team loop built on a blue-team operational foundation.

## Purpose

The goal is to make adversary simulation, replay, detection validation, investigation, and improvement part of one repeatable workflow instead of separate exercises.

## Core loop

1. define or capture a scenario
2. replay or simulate the scenario through the same bounded ingest path
3. run deterministic detection and correlation
4. investigate using durable evidence and operator-visible summaries
5. compare expected outcomes with observed outcomes
6. turn misses, noise, or analyst feedback into replayable improvements
7. rerun the scenario to confirm the improvement

## Why this matters

A purple-team loop is only useful if it is cheap to repeat and honest to evaluate. HackTUI aims to support that by favoring:
- deterministic replay over memory of what happened
- durable evidence over narrative-only conclusions
- bounded workflows over hidden automation
- explicit coverage and regression thinking over one-off wins

## Relationship to blue-team operations

Blue-team workflows remain the operational core:
- investigations
- approvals
- audit trails
- operator review

Purple-team work builds on that core by adding structured validation:
- did the scenario trigger the expected detections?
- did the investigation show the expected evidence?
- what changed between versions?
- what should become a regression fixture?

## Role of the platform layers

- sensors and replay inputs provide observations
- the hub coordinates deterministic control-plane behavior
- the store preserves evidence, outcomes, and audit records
- the terminal surface shows the workflow honestly
- the agent layer can assist with analysis and improvement proposals, but does not replace evidence or operator judgment

## Success criteria

The model is working when:
- the same scenario can be rerun reliably
- expected versus observed outcomes are visible
- missed detections become explicit improvement work
- improvements can be revalidated without guesswork
- operator trust increases because conclusions are evidence-backed