defmodule HacktuiAgent.MCP.DispatchSafetyTest do
  @moduledoc """
  No tool may take down the MCP transport.

  `get_jido_responses` crashed every session: collectors emit `collector: :packet_capture`
  (an atom), an operator-precedence bug left it un-downcased, and
  `String.contains?(:packet_capture, "jido")` raised `FunctionClauseError` with no rescue
  anywhere in Dispatch -> Server -> Stdio.
  """
  use ExUnit.Case, async: true

  alias HacktuiAgent.MCP.Dispatch

  defmodule ExplodingQueryService do
    @moduledoc false
    def alert_queue(_repo), do: raise(ArgumentError, "boom")
    def sensor_logs(_repo), do: raise(ArgumentError, "boom")
    def case_timeline(_repo, _case_id), do: raise(ArgumentError, "boom")
  end

  test "a raising tool returns an error tuple instead of propagating" do
    assert {:error, %{tool: :get_latest_alerts}} =
             Dispatch.safe_call(:get_latest_alerts, %{}, query_service: ExplodingQueryService)
  end

  test "the caller survives a tool that raises" do
    _ = Dispatch.safe_call(:get_sensor_logs, %{}, query_service: ExplodingQueryService)
    assert Process.alive?(self())
  end

  test "the error carries the tool name and a reason for the audit trail" do
    assert {:error, %{tool: tool, reason: reason}} =
             Dispatch.safe_call(:get_case_timeline, %{"case_id" => "c-1"},
               query_service: ExplodingQueryService
             )

    assert tool == :get_case_timeline
    assert is_binary(reason)
  end
end
