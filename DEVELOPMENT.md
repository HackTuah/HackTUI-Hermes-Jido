# Development

## Local posture
- Default posture is safe and local-first.
- DB-backed work must be explicit.
- Demo verification should prefer deterministic data and bounded terminal output.

## Current focused test commands
- `mix test apps/hacktui_agent/test/hacktui_agent_jido_flow_test.exs`
- `mix test apps/hacktui_agent/test/integration/investigation_flow_db_integration_test.exs --include integration`

Note: running the integration file without `--include integration` will exclude those tests.

## Existing demo path in repo
- `mix demo.investigate`
- `mix demo.view`
- `mix demo.approve`

These are the commands to harden. Do not create a parallel demo path unless the existing one is proven unusable.

## Current demo hardening target
A reliable local command should:
1. Start the needed apps
2. Verify DB-backed mode explicitly
3. Seed deterministic `case-1` data
4. Run the investigation flow
5. Print a clean bounded summary

## Reporting standard
Every meaningful change should end with:
- exact files changed
- exact commands run
- exact failures or exclusions
- honest limitations
