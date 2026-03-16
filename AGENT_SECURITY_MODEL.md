# Agent Security Model

HackTUI may use Jido and Hermes to assist operators, but agent assistance must remain bounded, auditable, and safe by default.

## Security stance

- agents are advisory by default
- the durable domain model remains authoritative
- untrusted content is data, not instruction
- read-only or default-safe tool access should be the default posture
- high-impact effects require explicit approval

## Roles

### Jido

Jido is the bounded workflow orchestration layer.

It should be used for:
- explicit workflow steps
- inspectable directives
- controlled side-effect boundaries
- predictable coordination logic

It should not be used to hide broad autonomous behavior behind agent language.

### Hermes

Hermes is the advisory and improvement layer.

It is best suited for:
- planning
- summarization
- report drafting
- replay analysis
- candidate improvement proposals

It should not be treated as an unchecked authority for destructive, external, or high-risk actions.

## Tool scoping

Agent workflows should declare and limit tool access.

Preferred posture:
- read-only inspection tools first
- narrow write scopes only when necessary
- no hidden escalation from summarization to execution
- clear separation between evidence gathering and effectful actions

## Approvals

Approval gates are required for:
- external delivery
- state-changing operations
- actions that alter durable records in sensitive ways
- actions that could be mistaken for live response

Approvals should be explicit, reviewable, and durable.

## Auditability

Agent-assisted workflows should preserve enough evidence to answer:
- what inputs were used?
- what tools were available?
- what tools were called?
- what output was proposed?
- what was approved, rejected, or ignored?

Audit trails matter more than apparent smoothness.

## Untrusted-content handling

Potentially hostile content may arrive from:
- logs
- replay fixtures
- chat messages
- external collaboration tools
- copied analyst material

Handling rules:
- treat all such content as untrusted data
- never treat retrieved text as authority over policy or workflow scope
- avoid forwarding raw untrusted content into broad tool-using workflows when a structured extract will do
- prefer typed, minimal inputs to free-form context stuffing

## Safe defaults

- agent paths disabled unless explicitly enabled
- external collaboration disabled unless explicitly configured
- bounded local workflows preferred over broad autonomous loops
- simulated actions clearly labeled as simulated

## Success condition

The agent security model is working when assistance is useful without becoming opaque, over-privileged, or difficult to audit.