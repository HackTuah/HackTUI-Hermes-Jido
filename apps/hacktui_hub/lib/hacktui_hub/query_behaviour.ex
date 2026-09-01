defmodule HacktuiHub.QueryBehaviour do
  @moduledoc """
  The operator read surface, as consumed by the TUI, the MCP tools and the Slack boundary.

  `query_service` was injected as an untyped `module()` at every call site
  (`MCP.Dispatch`, `HacktuiCollab.Slack.Router`, `HacktuiTui.Workflows.AlertQueue`,
  `HacktuiAgent.InvestigationFlow`), so a double could return a shape the real service
  never produces and nothing would notice until runtime. `FakeQueryRepo.all/1` returning
  a bare `{source, schema}` tuple — which `normalize_alert/1` cannot accept — is that bug.

  Naming the contract is also the prerequisite for the read models being a published,
  stable API rather than anonymous maps whose keys are defined inside a private function.
  """

  @callback alert_queue(module()) :: [map()]
  @callback case_board(module()) :: [map()]
  @callback approval_inbox(module()) :: [map()]
  @callback audit_events(module()) :: [map()]
  @callback case_timeline(module(), String.t()) :: [map()]
  @callback sensor_logs(module()) :: [map()]
  @callback jido_responses(module()) :: [map()]
  @callback investigation_context(module(), String.t()) :: map()
end
