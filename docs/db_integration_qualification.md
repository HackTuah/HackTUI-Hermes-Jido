# DB Integration Qualification

Status: controlled local qualification for the DB-backed runtime path.

## 1. Qualification plan

### What must be proven
- migrations run successfully against a real PostgreSQL instance
- Repo starts in DB-backed mode when explicitly enabled
- safe no-repo mode remains intact and does not require DB
- hub -> store -> read-model round trip works against a real DB
- alert persistence round trip works
- case persistence round trip works
- action request persistence round trip works
- audit persistence round trip works
- hub query service returns expected read models from persisted data

### In scope
- local Postgres-backed integration qualification
- config-gated Repo startup
- DB-backed hub/store/runtime composition
- honest smoke checks for:
  - safe no-repo mode
  - db-backed mode
  - db-backed + hub mode
  - db-backed + agent-enabled mode

### Out of scope
- Slack transport qualification
- MCP server deployment qualification
- production deployment qualification
- sensor transport qualification
- new features or new Jido workflows

### Test environments required
- local Postgres reachable on localhost:5432
- `HACKTUI_DB_PASS` loaded from `.env`
- dedicated qualification database:
  - `hacktui_qualification_test`

### Acceptance criteria
- full umbrella default suite remains green
- integration tests are separated from unit/default tests
- real DB integration path is runnable with explicit commands
- migrations apply cleanly to the qualification DB
- DB-backed runtime and query/read-model paths succeed against real persistence
- docs describe prerequisites, env vars, startup, health checks, and cleanup truthfully

### Failure criteria
- integration tests silently depend on DB without explicit opt-in
- migrations fail on the qualification DB
- Repo cannot start when explicitly enabled
- DB-backed round trips only work with mocks and not with the real Repo
- docs imply more than the tests actually prove

### Rollback / cleanup approach
- use a dedicated qualification database
- truncate workflow tables between integration tests
- drop the qualification database manually when done if a full reset is desired
- default unit/test path remains DB-independent

## 2. Exact env vars used in qualification

Required:
- `HACKTUI_DB_PASS`

Used explicitly in this pass:
- `HACKTUI_DB_NAME=hacktui_qualification_test`
- `HACKTUI_START_REPO=true`
- `HACKTUI_AGENT_BACKENDS=jido` for the agent-enabled smoke path only

Defaulted if not overridden:
- `HACKTUI_DB_USER=hacktui`
- `HACKTUI_DB_HOST=localhost`
- `HACKTUI_DB_PORT=5432`

## 3. Exact commands to run locally

### A. Source credentials
- `set -a && source .env && set +a`

### B. Create the qualification database once
- `PGPASSWORD="$HACKTUI_DB_PASS" psql -h localhost -U hacktui -d postgres -c 'create database hacktui_qualification_test;'`

If it already exists, Postgres will report that separately. Do not run qualification against the shared dev DB when you want migration truth.

### C. Run migrations against the qualification DB
- `export HACKTUI_DB_NAME=hacktui_qualification_test`
- `export HACKTUI_START_REPO=true`
- `cd apps/hacktui_store`
- `MIX_ENV=test mix ecto.migrate`

### D. Run default umbrella truth
- `cd ../..`
- `mix format`
- `mix test`

### E. Run store integration qualification
- `cd apps/hacktui_store`
- `MIX_ENV=test mix test --include integration test/integration/store_db_integration_test.exs`

### F. Run hub integration qualification
- `cd ../hacktui_hub`
- `MIX_ENV=test mix test --include integration test/integration/hub_db_integration_test.exs`

### G. Run collab DB smoke qualification
- `cd ../hacktui_collab`
- `export HACKTUI_COLLAB_PROVIDERS=slack`
- `MIX_ENV=test mix test --include integration test/integration/collab_db_smoke_test.exs`

### H. Run agent-enabled DB smoke qualification
- `cd ../hacktui_agent`
- `export HACKTUI_AGENT_BACKENDS=jido`
- `MIX_ENV=test mix test --include integration test/integration/agent_db_smoke_test.exs`

### I. Run repeated reset/migrate qualification
- `cd ../hacktui_store`
- `MIX_ENV=test mix test --include integration test/integration/store_db_reset_cycle_test.exs`
- `cd ../hacktui_hub`
- `MIX_ENV=test mix test --include integration test/integration/hub_restart_smoke_test.exs`

## 4. Qualification results from this pass

Qualified in a controlled local environment:
- migrations apply successfully to `hacktui_qualification_test`
- Repo starts in DB-backed mode when explicitly enabled
- alert persistence round trip works against real Postgres
- case persistence round trip works against real Postgres
- action request persistence round trip works against real Postgres
- audit persistence round trip works against real Postgres
- hub -> store -> read-model round trip works against real Postgres
- db-backed + hub smoke path works
- db-backed + collab smoke path works as a bounded runtime/startup qualification
- db-backed + agent-enabled smoke path works in bounded form
- qualification DB reset and migrate cycle works against the dedicated qualification DB

Not qualified in this pass:
- Slack transport against a real Slack workspace
- production deployment behavior
- full live MCP serving/runtime qualification

## 5. Separation of truth

Unit/default truth:
- `mix test` from repo root
- integration tests excluded by default
- does not prove real DB behavior

Integration truth:
- explicit `--include integration`
- real PostgreSQL required
- proves only the DB-backed paths actually exercised by those tests
