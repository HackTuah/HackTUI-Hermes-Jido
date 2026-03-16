# HackTUI Project Brief (Updated)

HackTUI is an **Elixir umbrella project** building a **terminal‑first
purple‑team security operations platform** on the BEAM.

The platform is designed to combine:

-   deterministic detection and investigation
-   distributed sensor collection
-   replay-driven validation
-   bounded automation
-   human‑visible operational control

HackTUI is intentionally **operator‑first**, prioritizing transparency,
determinism, and auditability over opaque automation.

------------------------------------------------------------------------

# Mission

Build a **BEAM‑native distributed security platform** that favors:

-   deterministic detection over opaque automation\
-   replay‑first validation over anecdotal confidence\
-   evidence‑driven investigations over narrative summaries\
-   continuous improvement over one‑off exercises\
-   bounded assistance over unchecked autonomous agents

The system should always prioritize **observable truth** over
convenience.

------------------------------------------------------------------------

# Platform Architecture

HackTUI is implemented as an **Elixir umbrella application** with
clearly separated concerns.

Core components include:

-   `hacktui_core` --- domain models, commands, events, envelopes
-   `hacktui_store` --- persistence and projections (Postgres)
-   `hacktui_hub` --- ingest, detection, casework, approvals, query
    surface
-   `hacktui_sensor` --- remote collectors and observation forwarders
-   `hacktui_agent` --- bounded investigation and analysis flows
-   `hacktui_tui` --- terminal‑first operator interface
-   `hacktui_collab` --- collaboration and escalation integrations

This separation enforces **clean boundaries between collection,
analysis, storage, and operator interaction**.

------------------------------------------------------------------------

# Distributed System Model

HackTUI operates as a **distributed BEAM cluster** composed of two node
roles.

## Hub Nodes

Hub nodes form the **control plane and analysis plane**.

Responsibilities:

-   authoritative ingest
-   deterministic detection pipeline
-   casework and investigation coordination
-   approval workflows
-   query services for TUI
-   Postgres‑backed durable system state

Multiple hub nodes may run simultaneously and share the same database.

## Sensor Nodes

Sensor nodes run close to monitored systems and perform:

-   packet observation
-   journald ingestion
-   process signal collection
-   telemetry normalization
-   forwarding observations to hub ingest services

Sensors remain **stateless and replaceable**.

------------------------------------------------------------------------

# Observation Flow

The canonical data path is:

collector\
→ normalized observation envelope\
→ sensor forwarder\
→ hub ingest service\
→ AcceptObservation command\
→ ObservationAccepted event\
→ detection pipeline\
→ alert persistence and projections\
→ operator visibility in the TUI

Sensors **never write directly to the database**.

Hub nodes remain the authoritative ingest and decision point.

------------------------------------------------------------------------

# Replay‑First Validation

HackTUI emphasizes **replay‑driven validation**.

Deterministic fixtures and replay runners allow:

-   repeatable investigation flows
-   regression testing of detection logic
-   validation of alert generation
-   reproducible operator output

Replay validation ensures that platform behavior is **testable and
explainable**.

------------------------------------------------------------------------

# Purple‑Team Direction

HackTUI is evolving toward a **continuous purple‑team platform**.

Planned capabilities include:

-   adversary exercise orchestration
-   ATT&CK technique validation loops
-   replay‑based regression of detection coverage
-   proof‑carrying alerts and investigations
-   Hermes‑assisted investigation and improvement workflows

The goal is a **continuous improvement cycle**:

simulate → detect → investigate → validate → improve.

------------------------------------------------------------------------

# Current Capabilities

Implemented or validated components include:

-   deterministic seed investigation data
-   bounded investigation flow using Jido
-   replay ingestion and validation harness
-   DB‑backed hub integration tests
-   distributed hub/sensor architecture foundations
-   terminal‑first operational interface

These provide a stable **blue‑team investigative core** that will
support future purple‑team functionality.

------------------------------------------------------------------------

# Current Focus

Active development focuses on:

-   deterministic replay validation
-   distributed hub and sensor operation
-   reliable ingest and detection flows
-   bounded investigation automation
-   operator‑visible system state

Every new capability must integrate with the **existing command/event
architecture**.

------------------------------------------------------------------------

# Out of Scope (For Now)

The following are explicitly out of scope at this stage:

-   production readiness claims
-   autonomous destructive response
-   hidden side effects or background automation
-   undocumented system behavior
-   parallel systems bypassing the event pipeline

HackTUI should remain **honest about its capabilities and maturity**.

------------------------------------------------------------------------

# Operating Philosophy

HackTUI must always communicate the truth about its state.

Rules:

-   what is deterministic must be replayable
-   what is advisory must be labeled advisory
-   what is simulated must be labeled simulated
-   what is planned must not be documented as implemented

Operator trust depends on **accurate system behavior and transparent
reporting**.

------------------------------------------------------------------------

# Current Status

The repository currently contains:

-   a structured umbrella architecture
-   a DB‑backed hub with deterministic replay validation
-   bounded investigation flows
-   distributed sensor and hub foundations
-   terminal‑first operator interaction

Full purple‑team automation and continuous adversary simulation remain
**planned capabilities**, not completed features.

HackTUI is presently a **blue‑team investigation platform with a clear
path toward purple‑team operations**.
