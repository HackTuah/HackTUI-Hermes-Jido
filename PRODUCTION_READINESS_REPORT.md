# Production Readiness Report

Date: 2026-03-15T15:42:41-04:00

Environment:
- .env loaded: yes
- HACKTUI_START_REPO=true
- HACKTUI_AGENT_BACKENDS=jido

## Postgres
/var/run/postgresql:5432 - accepting connections

## Compile
==> hacktui_core
Compiling 33 files (.ex)
Generated hacktui_core app
==> hacktui_store
Compiling 21 files (.ex)
Generated hacktui_store app
==> hacktui_sensor
Compiling 5 files (.ex)
Generated hacktui_sensor app
==> hacktui_hub
Compiling 26 files (.ex)
Generated hacktui_hub app
==> hacktui_collab
Compiling 9 files (.ex)
Generated hacktui_collab app
==> hacktui_agent
Compiling 15 files (.ex)
Generated hacktui_agent app
==> hacktui_tui
Compiling 11 files (.ex)
Generated hacktui_tui app

## Tests
### mix test
==> hacktui_core
Compiling 33 files (.ex)
Generated hacktui_core app
==> hacktui_store
Compiling 21 files (.ex)
Generated hacktui_store app
==> hacktui_sensor
Compiling 5 files (.ex)
Generated hacktui_sensor app
==> hacktui_hub
Compiling 26 files (.ex)
Generated hacktui_hub app
==> hacktui_collab
Compiling 9 files (.ex)
Generated hacktui_collab app
==> hacktui_agent
Compiling 15 files (.ex)
Generated hacktui_agent app
==> hacktui_tui
Compiling 11 files (.ex)
Generated hacktui_tui app
==> hacktui_core

15:42:44.362 [info] [hacktui_store] start_repo=false

15:42:44.377 [info] [hacktui_collab] enabled_providers=[]

15:42:44.528 [info] [hacktui_agent] enabled_backends=[]
Running ExUnit with seed: 544316, max_cases: 64

.......................
Finished in 0.06 seconds (0.06s async, 0.00s sync)
23 tests, 0 failures
==> hacktui_store
Running ExUnit with seed: 544316, max_cases: 64
Excluding tags: [integration: true]

.................
15:42:44.886 [notice] Application hacktui_store exited: :stopped

15:42:44.894 [info] [hacktui_store] start_repo=true

15:42:44.936 [error] Postgrex.Protocol (#PID<0.1469.0> ("db_conn_1")) failed to connect: ** (DBConnection.ConnectionError) tcp connect (127.0.0.1:65432): connection refused - :econnrefused

15:42:46.906 [error] Postgrex.Protocol (#PID<0.1469.0> ("db_conn_1")) failed to connect: ** (DBConnection.ConnectionError) tcp connect (127.0.0.1:65432): connection refused - :econnrefused

15:42:50.929 [notice] Application hacktui_store exited: :stopped
.
15:42:50.929 [info] [hacktui_store] start_repo=false
.......
Finished in 6.2 seconds (0.1s async, 6.0s sync)
25 tests, 0 failures (8 excluded)
==> hacktui_sensor
Running ExUnit with seed: 544316, max_cases: 64
Excluding tags: [integration: true]



  1) test starts collector supervision boundaries and ingests live observations locally (HacktuiSensorTest)
     apps/hacktui_sensor/test/hacktui_sensor_test.exs:6
     condition was not met in time
     code: assert_eventually(fn ->
     stacktrace:
       test/hacktui_sensor_test.exs:20: (test)



  2) test declares expected collector categories (HacktuiSensorTest)
     apps/hacktui_sensor/test/hacktui_sensor_test.exs:33
     Assertion with in failed
     code:  assert :packet_capture in HacktuiSensor.collectors()
     left:  :packet_capture
     right: [:journald, :process_signals, :network]
     stacktrace:
       test/hacktui_sensor_test.exs:34: (test)


Finished in 2.0 seconds (0.00s async, 2.0s sync)
2 tests, 2 failures
==> hacktui_hub
Running ExUnit with seed: 544316, max_cases: 64
Excluding tags: [integration: true]



  1) test replay accepted observations derive deterministic purple exercises (HacktuiHub.Replay.PurpleRunnerTest)
     apps/hacktui_hub/test/hacktui_hub/replay/purple_runner_test.exs:7
     ** (ArgumentError) the following keys must also be given when building struct HacktuiCore.Commands.AcceptObservation: [:summary, :raw_message, :severity, :confidence]
     code: accepted = Runner.run_fixture!("case-1")
     stacktrace:
       (hacktui_core 0.1.0) HacktuiCore.Commands.AcceptObservation.__struct__/1
       (elixir 1.19.2) lib/kernel.ex:2549: Kernel.struct!/2
       (hacktui_hub 0.1.0) lib/hacktui_hub/replay/runner.ex:51: HacktuiHub.Replay.Runner.accept_envelope!/2
       (elixir 1.19.2) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/hacktui_hub/replay/purple_runner_test.exs:8: (test)



  2) test replay envelopes are accepted through ingest (HacktuiHub.Replay.RunnerIngestTest)
     apps/hacktui_hub/test/hacktui_hub/replay/runner_ingest_test.exs:8
     ** (ArgumentError) the following keys must also be given when building struct HacktuiCore.Commands.AcceptObservation: [:summary, :raw_message, :severity, :confidence]
     code: |> Runner.run_envelopes!()
     stacktrace:
       (hacktui_core 0.1.0) HacktuiCore.Commands.AcceptObservation.__struct__/1
       (elixir 1.19.2) lib/kernel.ex:2549: Kernel.struct!/2
       (hacktui_hub 0.1.0) lib/hacktui_hub/replay/runner.ex:51: HacktuiHub.Replay.Runner.accept_envelope!/2
       (elixir 1.19.2) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/hacktui_hub/replay/runner_ingest_test.exs:18: (test)

..

  3) test run_fixture!/1 replays fixtures into ordered accepted observations (HacktuiHub.ReplayLoaderTest)
     apps/hacktui_hub/test/hacktui_hub_replay_loader_test.exs:29
     ** (ArgumentError) the following keys must also be given when building struct HacktuiCore.Commands.AcceptObservation: [:summary, :raw_message, :severity, :confidence]
     code: accepted = Runner.run_fixture!("fixtures/replay/case-1.jsonl")
     stacktrace:
       (hacktui_core 0.1.0) HacktuiCore.Commands.AcceptObservation.__struct__/1
       (elixir 1.19.2) lib/kernel.ex:2549: Kernel.struct!/2
       (hacktui_hub 0.1.0) lib/hacktui_hub/replay/runner.ex:51: HacktuiHub.Replay.Runner.accept_envelope!/2
       (elixir 1.19.2) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/hacktui_hub_replay_loader_test.exs:30: (test)

..................

  4) test case-1 accepted observations derive alert-like internal results (HacktuiHub.ReplayIngestTest)
     apps/hacktui_hub/test/replay_ingest_test.exs:72
     ** (ArgumentError) the following keys must also be given when building struct HacktuiCore.Commands.AcceptObservation: [:summary, :raw_message, :severity, :confidence]
     code: accepted = Runner.run_fixture!("case-1")
     stacktrace:
       (hacktui_core 0.1.0) HacktuiCore.Commands.AcceptObservation.__struct__/1
       (elixir 1.19.2) lib/kernel.ex:2549: Kernel.struct!/2
       (hacktui_hub 0.1.0) lib/hacktui_hub/replay/runner.ex:51: HacktuiHub.Replay.Runner.accept_envelope!/2
       (elixir 1.19.2) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/replay_ingest_test.exs:73: (test)



  5) test case-1 replay produces accepted observations (HacktuiHub.ReplayIngestTest)
     apps/hacktui_hub/test/replay_ingest_test.exs:39
     ** (ArgumentError) the following keys must also be given when building struct HacktuiCore.Commands.AcceptObservation: [:summary, :raw_message, :severity, :confidence]
     code: results = Runner.run_fixture!("case-1")
     stacktrace:
       (hacktui_core 0.1.0) HacktuiCore.Commands.AcceptObservation.__struct__/1
       (elixir 1.19.2) lib/kernel.ex:2549: Kernel.struct!/2
       (hacktui_hub 0.1.0) lib/hacktui_hub/replay/runner.ex:51: HacktuiHub.Replay.Runner.accept_envelope!/2
       (elixir 1.19.2) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/replay_ingest_test.exs:40: (test)


Finished in 0.1 seconds (0.1s async, 0.01s sync)
25 tests, 5 failures (3 excluded)
==> hacktui_collab
Running ExUnit with seed: 544316, max_cases: 64
Excluding tags: [integration: true]

..........
Finished in 0.09 seconds (0.09s async, 0.00s sync)
10 tests, 0 failures (1 excluded)
==> hacktui_agent
Running ExUnit with seed: 544316, max_cases: 64
Excluding tags: [integration: true]

.....
15:42:53.455 [notice] Executing HacktuiAgent.Actions.Investigation.CorrelateContext with params: %{} and context: %{state: %{status: :queued, context: %{alerts: [%{size: 3, type: :map, __truncated_depth__: 4}, %{size: 3, type: :map, __truncated_depth__: 4}, %{size: 3, type: :map, __truncated_depth__: 4}], timeline: [%{size: 3, type: :map, __truncated_depth__: 4}, %{size: 3, type: :map, __truncated_depth__: 4}]}, case_id: "case-1", correlation: %{}, report_draft: %{}}, action_metadata: %{name: "investigation_correlate_context", description: "Correlate case context and alert context to identify shared indicators.", vsn: nil, category: nil, schema: [], output_schema: [], tags: [], compensation: %{timeout: 5000, enabled: false, max_retries: 1}}}

15:42:53.456 [notice] Executing HacktuiAgent.Actions.Investigation.DraftReport with params: %{} and context: %{state: %{status: :correlated, context: %{alerts: [%{size: 3, type: :map, __truncated_depth__: 4}, %{size: 3, type: :map, __truncated_depth__: 4}, %{size: 3, type: :map, __truncated_depth__: 4}], timeline: [%{size: 3, type: :map, __truncated_depth__: 4}, %{size: 3, type: :map, __truncated_depth__: 4}]}, case_id: "case-1", correlation: %{case_id: "case-1", shared_indicators: ["10.0.0.4", "malicious.example"], matched_alert_ids: ["alert-1", "alert-2"]}, report_draft: %{}}, action_metadata: %{name: "investigation_draft_report", description: "Draft a report from the correlated investigation state.", vsn: nil, category: nil, schema: [], output_schema: [], tags: [], compensation: %{timeout: 5000, enabled: false, max_retries: 1}}}

15:42:53.457 [notice] Executing HacktuiAgent.Actions.Investigation.EmitCompletion with params: %{} and context: %{state: %{status: :report_drafted, context: %{alerts: [%{size: 3, type: :map, __truncated_depth__: 4}, %{size: 3, type: :map, __truncated_depth__: 4}, %{size: 3, type: :map, __truncated_depth__: 4}], timeline: [%{size: 3, type: :map, __truncated_depth__: 4}, %{size: 3, type: :map, __truncated_depth__: 4}]}, case_id: "case-1", correlation: %{case_id: "case-1", shared_indicators: ["10.0.0.4", "malicious.example"], matched_alert_ids: ["alert-1", "alert-2"]}, report_draft: %{case_id: "case-1", summary: "Draft report for case-1: correlated alerts [alert-1, alert-2] across indicators [10.0.0.4, malicious.example]", shared_indicators: ["10.0.0.4", "malicious.example"], matched_alert_ids: ["alert-1", "alert-2"]}}, action_metadata: %{name: "investigation_emit_completion", description: "Emit an investigation completed signal for downstream consumers.", vsn: nil, category: nil, schema: [], output_schema: [], tags: [], compensation: %{timeout: 5000, enabled: false, max_retries: 1}}}
.......
Finished in 0.08 seconds (0.08s async, 0.00s sync)
12 tests, 0 failures (6 excluded)
==> hacktui_tui
Running ExUnit with seed: 544316, max_cases: 64
Excluding tags: [integration: true]

.............
Finished in 0.04 seconds (0.04s async, 0.00s sync)
13 tests, 0 failures
