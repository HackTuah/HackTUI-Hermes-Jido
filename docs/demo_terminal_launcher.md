# Demo terminal launcher

Purpose: provide the minimum honest terminal entrypoint for the current HackTUI bounded demo path.

This is not a full-screen interactive TUI.
The current terminal boundary is a rendered report produced by `HacktuiTui.DemoTerminalView` and surfaced through mix tasks in `apps/hacktui_hub/lib/mix/tasks/`.

## Current honest launcher

Use:

```bash
mix demo.investigate case-1
```

What it does today:

1. starts the umbrella app with `Mix.Task.run("app.start")`
2. calls `HacktuiHub.Demo.Runner.investigate/2`
3. ensures demo DB readiness
4. reseeds deterministic `case-1` data
5. runs the bounded investigation flow
6. renders a bounded terminal report via `HacktuiTui.DemoTerminalView.render/1`
7. prints a Slack preview payload and artifact paths
8. prints the follow-up approval command

## Why this is the minimum honest launcher

The inspected TUI boundary is intentionally narrow:

- `HacktuiTui.DemoTerminalView` renders a static terminal report string
- `mix demo.view case-1` also renders that report, but still does so by invoking the investigate path first
- there is no evidence in the inspected files of a richer interactive terminal session that should be claimed as available

So the honest product language is:

- bounded terminal demo view
- not a full-screen interactive TUI
- suitable for visible demo output only

## Related commands

View-only rendering path:

```bash
mix demo.view case-1
```

This currently re-runs investigation before rendering.
It should be treated as a convenience report command, not a pure read-only viewer.

Simulated approval step:

```bash
mix demo.approve case-1
```

This approves the pending simulated action request created during the investigate flow.

## Operator notes

- The runner currently seeds `case-1` unconditionally during investigation.
- The terminal view expects investigation status, matched alert IDs, shared indicators, summary, recommendation, and a health snapshot.
- Demo language should stay bounded and explicit: terminal report view, simulated approval, Slack preview, artifact output.

## Recommended next improvement

If a cleaner operator UX is needed, add one single demo entrypoint command that:

- verifies DB-backed mode explicitly
- seeds once
- runs investigation
- prints the bounded report
- prints artifact locations
- prints the next simulated approval command

That would improve operator ergonomics without overstating current TUI capability.
