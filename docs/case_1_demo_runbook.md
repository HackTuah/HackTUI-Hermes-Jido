# Case-1 demo runbook

This runbook documents the current bounded local demo flow based only on the inspected repo state.

## Scope

Case: `case-1`

Current visible path:

- deterministic seed path via `HacktuiStore.DemoSeed.seed_case_1!/1`
- bounded investigation execution via `HacktuiAgent.InvestigationFlow.run/2`
- orchestration via `HacktuiHub.Demo.Runner.investigate/2`
- bounded terminal rendering via `HacktuiTui.DemoTerminalView.render/1`
- optional simulated approval via `HacktuiHub.Demo.Runner.approve/2`

## Expected seeded narrative

The seeded case represents suspicious DNS activity around `malicious.example`.

Seeded alerts currently imply:

- `alert-1`: beaconing to `malicious.example`
- `alert-2`: repeat DNS lookup for `malicious.example`
- `alert-3`: benign lookup noise

The expected visible investigation output should therefore center on:

- matched alert IDs: `alert-1`, `alert-2`
- shared indicators: `10.0.0.4`, `malicious.example`
- a bounded summary for `case-1`
- a simulated containment recommendation for demo purposes

## Primary operator command

```bash
mix demo.investigate case-1
```

Observed behavior from code:

- starts apps
- ensures demo database readiness
- seeds deterministic `case-1`
- starts required runtime pieces
- runs the investigation flow
- creates or reuses a simulated pending action request
- renders the bounded terminal view
- prints a Slack preview structure
- prints artifact paths
- prints the next approval step

## Follow-up command

```bash
mix demo.approve case-1
```

Observed behavior from code:

- finds the pending simulated action request for the case
- applies simulated approval through hub runtime
- prints the resulting aggregate and health snapshot

## Honest limitations

- The current terminal layer is a bounded report renderer, not a full-screen interactive TUI.
- `mix demo.view case-1` is not a pure viewer; it currently reuses the investigate path first.
- The investigate runner currently reseeds `case-1` on each run.
- The approval step is explicitly simulated and should be described that way in all demos.
- No production-readiness claim is justified from this demo path alone.

## Recommended presentation language

Use wording like:

- "bounded terminal demo view"
- "deterministic local demo seed"
- "simulated approval request"
- "Slack preview payload"

Avoid wording like:

- "fully interactive TUI"
- "live SOC console"
- "production-ready workflow"

## Next implementation targets

The next repo tasks still appear to be:

1. normalize `InvestigationFlow.run/2` to accept nil, keyword opts, and map opts
2. keep seed data deterministic and visibly stable
3. add a single clean demo entrypoint command
4. verify end-to-end outputs and document exact limitations
