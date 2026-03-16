# Decisions

## 2026-03-07

### The BEAM runtime is the security platform foundation

HackTUI is built around Elixir/BEAM because supervision, fault isolation, and durable long-lived services are core platform requirements. The runtime itself is part of the security architecture, not just an implementation detail.

### Terminal-first remains the primary operator interface

The terminal surface remains primary because it supports local-first operation, bounded visibility, and explicit operator control. Collaboration surfaces may exist, but they should remain secondary to the authoritative terminal and store-backed workflow.

### Replay-first detection engineering is the target operating model

Detection and investigation quality should be validated through deterministic replay and regression workflows rather than anecdotal confidence. Planned purple-team capabilities should build on replayable scenarios and expected outcomes.

### Agents are advisory by default

Hermes-assisted workflows may plan, summarize, draft, or suggest improvements, but they are not authoritative responders by default. State-changing or externally visible effects require bounded workflows, policy checks, and approvals.

### Jido is for bounded orchestration, not unchecked autonomy

Jido-backed workflows are valuable because they make orchestration explicit and inspectable. The project should prefer directive-driven bounded flows over opaque automation chains.

### Keep the umbrella boundaries explicit

The current umbrella split remains the primary architecture. New work should land in the correct app boundary instead of re-centralizing logic.

### Reuse the existing demo path

The repo already has demo tasks, a demo runner, and a bounded terminal view. Hardening should extend that path instead of adding a second launcher.

### Keep default runtime safe

Repo startup and external provider activation remain explicit opt-ins. Local qualification is allowed; silent production-style startup is not.

### Truthful posture beats aspirational language

Documentation must distinguish clearly between:
- currently verified capabilities
- planned capabilities
- simulated behavior
- production-readiness claims

No document should present future purple-team or agent features as already proven when they are still roadmap items.