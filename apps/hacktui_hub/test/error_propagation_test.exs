defmodule HacktuiHub.ErrorPropagationTest do
  @moduledoc """
  A security console must never render "cannot read alerts" as "alerts=0".

  `safe_all_query/2` previously turned every DB error into `[]` for the alert queue,
  case board, approval inbox and audit events -- while the module's own docstring
  claimed "no hidden rescue path that turns real alerts into an empty queue".
  """
  use ExUnit.Case, async: false

  alias HacktuiHub.QueryService

  defmodule ExplodingRepo do
    @moduledoc false
    def all(_query), do: raise(DBConnection.ConnectionError, "connection refused")
  end

  defmodule EmptyRepo do
    @moduledoc false
    def all(_query), do: []
  end

  setup do
    Process.delete({QueryService, :last_query_failure})
    :ok
  end

  test "a failing repo is recorded as a failure, not an empty result" do
    assert QueryService.alert_queue(ExplodingRepo) == []

    failure = QueryService.last_query_failure()
    assert failure, "a read failure must be recorded so the operator can be told"
    assert failure.reason
  end

  test "a genuinely empty table records no failure" do
    assert QueryService.case_board(EmptyRepo) == []
    refute QueryService.last_query_failure()
  end

  test "the dashboard snapshot distinguishes empty from unreadable" do
    healthy = QueryService.live_dashboard_snapshot(EmptyRepo, [])
    assert healthy.alerts == []
    refute healthy.degraded

    broken = QueryService.live_dashboard_snapshot(ExplodingRepo, [])
    assert broken.alerts == []
    assert broken.degraded, "an unreadable repo must surface as DEGRADED"
  end

  test "an unavailable repo module is a failure, not silence" do
    assert QueryService.alert_queue(:definitely_not_a_module) == []
    assert QueryService.last_query_failure().reason == :repo_unavailable
  end
end
