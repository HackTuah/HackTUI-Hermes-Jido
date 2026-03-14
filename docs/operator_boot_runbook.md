# Operator Boot Runbook

## Distributed sensor to hub boot

For clustered deployment, run the hub and sensor as named distributed Erlang nodes with the same cookie. Set `HACKTUI_HUB_NODE` on sensor nodes so incoming observations are forwarded to the hub node instead of the local sensor process.

Example hub boot:

`iex --sname hub --cookie hacktui -S mix phx.server`

Example sensor boot:

`RELEASE_DISTRIBUTION=name RELEASE_NODE=sensor@host RELEASE_COOKIE=hacktui HACKTUI_HUB_NODE=hub@host _build/prod/rel/hacktui_sensor/bin/hacktui_sensor start`

Notes:
- `HACKTUI_HUB_NODE` may be unset for single-node/local mode.
- Hub and sensor must share the same cookie and be mutually resolvable by node name.
- Verify reachability with `Node.connect(:'hub@host')` or `epmd -names` before sending traffic.
- Real incoming traffic should enter through the sensor boundary, which now forwards `AcceptObservation` commands to the remote hub ingest service when configured.


Status: current operator runbook for the repo as it exists now.

## 1. Prerequisites

- Elixir 1.19+
- Erlang/OTP compatible with the repo
- PostgreSQL running on the configured host/port for DB-backed mode
- project `.env` file containing `HACKTUI_DB_PASS`

Important
- Use `source .env` rather than copying secrets into commands or docs.
- For integration qualification, use a dedicated database instead of the shared dev DB.

## 2. Safe no-repo boot sequence

Commands
- `mix format`
- `mix test`
- `iex -S mix`
- `Application.ensure_all_started(:hacktui_hub)`
- `Application.ensure_all_started(:hacktui_tui)`

Health checks
- `HacktuiStore.Health.status()`
- `HacktuiCollab.Health.status()`
- `HacktuiAgent.Health.status()`
- `HacktuiHub.Health.status()`

Expected
- store mode: `:safe_no_repo`
- collab mode: `:disabled`
- agent mode: `:disabled`

## 3. DB-backed boot sequence

Commands
- `set -a && source .env && set +a`
- `export HACKTUI_START_REPO=true`
- optional: `export HACKTUI_DB_NAME=hacktui_qualification_test`
- `iex -S mix`
- `Application.ensure_all_started(:hacktui_store)`
- `Application.ensure_all_started(:hacktui_hub)`

Health checks
- `HacktuiStore.Health.status()`
- `HacktuiHub.Health.status()`

Expected
- store mode: `:db_backed`
- `repo_enabled?` is true
- `repo_started?` is true

## 4. Migration sequence

For qualification or local DB-backed work:
- `set -a && source .env && set +a`
- `export HACKTUI_DB_NAME=hacktui_qualification_test`
- `export HACKTUI_START_REPO=true`
- `cd apps/hacktui_store`
- `MIX_ENV=test mix ecto.migrate`

If the qualification DB does not exist yet:
- `PGPASSWORD="$HACKTUI_DB_PASS" psql -h localhost -U hacktui -d postgres -c 'create database hacktui_qualification_test;'`

## 5. Agent-enabled boot sequence

Commands
- `set -a && source .env && set +a`
- `export HACKTUI_START_REPO=true`
- `export HACKTUI_DB_NAME=hacktui_qualification_test`
- `export HACKTUI_AGENT_BACKENDS=jido`
- `iex -S mix`
- `Application.ensure_all_started(:hacktui_store)`
- `Application.ensure_all_started(:hacktui_hub)`
- `Application.ensure_all_started(:hacktui_agent)`

Health checks
- `HacktuiAgent.Health.status()`
- `HacktuiHub.Health.status()`

Expected
- agent mode: `:jido_enabled`
- `jido_enabled?` is true

Current real scope
- bounded Jido investigation flow only
- no broader autonomous runtime claim

## 6. Collaboration-enabled boot sequence

Commands
- `export HACKTUI_COLLAB_PROVIDERS=slack`
- `iex -S mix`
- `Application.ensure_all_started(:hacktui_hub)`
- `Application.ensure_all_started(:hacktui_collab)`

Health checks
- `HacktuiCollab.Health.status()`
- `HacktuiHub.Health.status()`

Expected
- collab mode: `:enabled`
- enabled providers include `:slack`

Current real scope
- boundary runtime only
- full Slack transport is not qualified in this pass

## 7. Qualification startup sequence

Run in this order:
1. source env
2. select qualification DB name
3. run migrations
4. run default umbrella suite
5. run store integration qualification
6. run hub integration qualification
7. run agent-enabled DB smoke qualification if desired

## 8. Shutdown and cleanup sequence

To stop applications in IEx:
- `Application.stop(:hacktui_agent)`
- `Application.stop(:hacktui_collab)`
- `Application.stop(:hacktui_hub)`
- `Application.stop(:hacktui_store)`

To drop the qualification database when you want a full reset:
- `set -a && source .env && set +a`
- `PGPASSWORD="$HACKTUI_DB_PASS" psql -h localhost -U hacktui -d postgres -c 'drop database if exists hacktui_qualification_test;'`

## 9. Minimal operator boot checks

Always verify:
- `HacktuiStore.Health.status()`
- `HacktuiCollab.Health.status()`
- `HacktuiAgent.Health.status()`
- `HacktuiHub.Health.status()`

If the reported mode does not match the env flags you set, stop and correct config before proceeding.


## 7. Repeated reset and restart qualification

Use this when you want to prove the dedicated qualification DB and db-backed hub runtime can be reset and restarted cleanly.

Commands:
- `set -a && source .env && set +a`
- `export HACKTUI_DB_NAME=hacktui_qualification_test`
- `export HACKTUI_START_REPO=true`
- `cd apps/hacktui_store`
- `MIX_ENV=test mix test --include integration test/integration/store_db_reset_cycle_test.exs`
- `cd ../hacktui_hub`
- `MIX_ENV=test mix test --include integration test/integration/hub_restart_smoke_test.exs`

What this proves:
- the dedicated qualification DB can be reset and migrated again
- db-backed hub/store runtime can start, stop, and start again cleanly in a controlled local setup

What this does not prove:
- production restart semantics
- HA or distributed restart behavior
