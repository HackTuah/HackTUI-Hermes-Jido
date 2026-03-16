# Runtime Smoke Expansion Plan

Status: short execution plan for controlled DB-backed runtime integration and smoke expansion.

1. Runtime paths to exercise
- safe no-repo mode
- db-backed mode
- db-backed + hub mode
- db-backed + collab mode, only as a bounded runtime/startup smoke path
- db-backed + agent-enabled mode in its current bounded form
- repeated startup/shutdown for db-backed hub/store where practical
- repeated reset/migrate cycle on the dedicated qualification DB where practical

2. What each smoke path proves
- safe no-repo mode proves the default runtime remains DB-independent and keeps gated boundaries off
- db-backed mode proves explicit Repo startup and health reporting are real
- db-backed + hub mode proves the hub can start over a live Repo and expose read/query paths
- db-backed + collab mode proves the collab boundary can be enabled without requiring live Slack transport
- db-backed + agent-enabled mode proves the bounded Jido runtime path can be enabled over the DB-backed runtime
- repeated startup/shutdown proves the runtime can be stopped and restarted cleanly in a controlled local environment
- repeated reset/migrate proves the dedicated qualification DB can be returned to a known schema state and migrated again

3. What each smoke path does not prove
- none of these paths prove production readiness
- db-backed mode does not prove production-grade DB operations
- collab smoke does not prove Slack transport or delivery reliability
- agent-enabled smoke does not prove broad Jido adoption or general autonomous behavior
- repeated local restarts do not prove production restart semantics

4. Required environment assumptions
- PostgreSQL reachable on localhost:5432
- `.env` provides `HACKTUI_DB_PASS`
- qualification DB name is explicitly set to `hacktui_qualification_test`
- non-default runtime flags are set explicitly per smoke path

5. Acceptance criteria
- default suite remains green
- smoke/integration tests are explicitly separated from default tests
- each exercised mode reports expected health/status values
- qualification DB reset/migrate cycle passes cleanly
- no non-default runtime path is silently enabled

6. Failure criteria
- any default test path unexpectedly requires DB
- any smoke path depends on undocumented environment setup
- any enabled/disabled boundary state differs from the explicit runtime mode selected
- any smoke path implies stronger claims than the test actually proves

7. Cleanup/reset procedure
- use the dedicated qualification DB only
- stop started applications explicitly in test cleanup
- truncate workflow tables between DB integration tests
- for reset-cycle qualification, reset the schema and rerun migrations explicitly
