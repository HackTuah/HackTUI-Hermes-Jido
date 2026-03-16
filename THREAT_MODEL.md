# Threat Model

## Protected assets

- alert, case, and investigation records
- approval requests and decisions
- audit history and operator-visible summaries
- local demo and future replay artifacts
- credentials and provider configuration
- agent run context, tool results, and generated outputs

## Primary trust boundaries

- local terminal operator boundary
- local Postgres boundary
- optional collaboration/provider boundary
- sensor and replay input boundary
- agent and orchestration boundary

## Core security assumptions

- the local runtime is the authoritative control plane
- untrusted content may arrive from logs, sensors, Slack, fixtures, or copied analyst material
- agent-visible content must be treated as data, not instructions
- external providers are optional and must fail closed when disabled or misconfigured

## Current operational risks

- schema/query drift causing confusing or silent failures
- nondeterministic demo data leading to misleading operator conclusions
- simulated actions being mistaken for real actions
- unbounded output obscuring human review
- external provider paths exposing more data than intended

## Agent and LLM-specific risks

### Prompt injection

Risk:
- untrusted content may contain adversarial instructions intended to redirect agent behavior
- logs, chat messages, replay fixtures, or pasted artifacts may try to override system intent

Mitigations:
- bounded orchestration through explicit workflow steps
- untrusted-content handling rules that treat retrieved text as evidence, not authority
- approval gates for state-changing or externally visible actions
- audit trails for prompts, tool calls, outputs, and approvals where appropriate

### Tool misuse

Risk:
- an agent may select an unsafe tool or use a safe tool unsafely
- broad tool access can turn a summarization workflow into an execution risk

Mitigations:
- read-only or default-safe tools by default
- explicit tool scoping per workflow
- policy checks before non-read-only effects
- small, inspectable workflow surfaces instead of unrestricted autonomy

### Data exfiltration

Risk:
- sensitive investigation data could be sent to external tools or collaboration surfaces without necessity

Mitigations:
- local-first defaults
- minimized external egress
- explicit provider enablement and configuration gates
- redaction and summary-first delivery patterns
- durable audit records for outbound delivery paths

### Excessive autonomy

Risk:
- agents could be mistaken for authoritative responders and take actions beyond approved scope

Mitigations:
- agents are advisory by default
- Jido directives remain bounded and inspectable
- high-impact actions require explicit approval gates
- the durable domain model, not the agent, remains the source of truth

## Architectural controls

- bounded orchestration rather than hidden chains of side effects
- append-friendly audit trails for commands, transitions, approvals, and deliveries
- production-safe defaults with opt-in activation for DB, collaboration, and agent paths
- terminal-first operator review before implying action
- deterministic replay as a future validation control for regressions and safety checks

## Out of scope for current claims

- multi-tenant isolation
- full production authn/authz posture
- Internet-exposed deployment hardening
- fully qualified autonomous response
- broad external agent integrations without additional controls