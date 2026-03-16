# Failure Modes and Recovery Notes

Status: current known failure and recovery notes.

## 1. Repo disabled unexpectedly

Symptoms
- `HacktuiStore.Health.status().mode` returns `:safe_no_repo`
- DB-backed features are unavailable

Likely cause
- `HACKTUI_START_REPO` was not set to `true`
- `.env` was not sourced

Recovery
- `set -a && source .env && set +a`
- `export HACKTUI_START_REPO=true`
- restart the relevant applications
- re-check `HacktuiStore.Health.status()`

## 2. Migration fails with duplicate_table on shared dev DB

Symptoms
- `mix ecto.migrate` fails with duplicate table errors

Likely cause
- you ran qualification migrations against a shared database that already contained manually created or previously unmanaged tables

Recovery
- do not use the shared dev DB for qualification proof
- switch to the dedicated qualification DB:
  - `export HACKTUI_DB_NAME=hacktui_qualification_test`
- create it if needed
- rerun migrations there

## 3. Repo enabled but DB unavailable

Symptoms
- Repo process starts, but DB queries fail
- local logs show connection failures such as `tcp connect ... :econnrefused`
- DB-backed operations fail even though `start_repo` is enabled

Likely cause
- PostgreSQL not running
- wrong host, port, user, password, or database name

Recovery
- verify PostgreSQL is running
- verify `.env` values
- verify `HACKTUI_DB_USER`, `HACKTUI_DB_HOST`, `HACKTUI_DB_PORT`, and `HACKTUI_DB_NAME`
- run a direct smoke query against the intended DB
- rerun migrations against the intended DB
- restart and re-check `HacktuiStore.Health.status()`

## 4. Integration tests fail because DB credentials are missing

Symptoms
- integration tests abort with an explicit missing-env error

Likely cause
- `HACKTUI_DB_PASS` was not exported into the shell

Recovery
- `set -a && source .env && set +a`
- rerun the integration command

## 5. Agent runtime disabled

Symptoms
- `HacktuiAgent.Health.status().mode` is `:disabled`
- Jido instance not started

Likely cause
- `HACKTUI_AGENT_BACKENDS` not set

Recovery
- `export HACKTUI_AGENT_BACKENDS=jido`
- restart agent app
- re-check `HacktuiAgent.Health.status()`

## 6. Collaboration runtime disabled

Symptoms
- `HacktuiCollab.Health.status().mode` is `:disabled`

Likely cause
- `HACKTUI_COLLAB_PROVIDERS` not set

Recovery
- `export HACKTUI_COLLAB_PROVIDERS=slack`
- restart collab app
- re-check `HacktuiCollab.Health.status()`

## 7. Full suite green but runtime not production-ready

Symptoms
- tests pass
- runtime still lacks full deployment and transport maturity

Explanation
- the suite proves unit truth plus controlled DB-backed integration truth
- it does not prove production deployment readiness

Recovery
- do not make production claims based only on this qualification pass
- continue with DB-backed runtime integration and operational hardening next


## 8. Qualification DB reset/migrate failures

Symptoms
- reset-cycle integration test fails
- migration rerun does not recreate expected tables

Likely cause
- qualification DB not dedicated or not writable by the configured user
- schema reset failed partway through

Recovery
- verify you are using `hacktui_qualification_test`
- verify the `hacktui` user owns or can recreate the public schema in that DB
- rerun the dedicated reset-cycle integration test
