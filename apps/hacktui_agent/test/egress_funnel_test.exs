defmodule HacktuiAgent.MCP.EgressFunnelTest do
  @moduledoc """
  Masking must be a funnel, not a convention.

  It was four hand-placed `|> Egress.mask()` calls at individual call sites, so
  `draft_report` -- which embeds the same case timeline `get_case_timeline` masks -- was
  never masked. A reviewer found it reachable over the wire from an advertised tool.
  """
  use ExUnit.Case, async: true

  alias HacktuiAgent.MCP.Dispatch

  defmodule Svc do
    @moduledoc false
    def alert_queue, do: [%{"src" => "10.0.0.4"}]
    def sensor_logs(_repo), do: [%{"src" => "10.0.0.4"}]
    def jido_responses(_repo), do: [%{"src" => "10.0.0.4"}]
    def case_timeline(_repo, _id), do: [%{"src" => "10.0.0.4", "site" => "192.168.1.1"}]

    def draft_report(_id, _opts),
      do: %{summary: "s", timeline: [%{"src" => "10.0.0.4", "site" => "192.168.1.1"}]}

    def propose_action(spec, _opts), do: Map.put(spec, :host, "10.0.0.4")
  end

  defmodule Thrower do
    @moduledoc false
    def alert_queue, do: throw(:boom)
  end

  defp opts, do: [query_service: Svc, proposal_service: Svc, repo: :stub]

  test "draft_report is masked identically to get_case_timeline" do
    {:ok, report} = Dispatch.safe_call(:draft_report, %{case_id: "c-1"}, opts())
    {:ok, timeline} = Dispatch.safe_call(:get_case_timeline, %{case_id: "c-1"}, opts())

    assert report.timeline == timeline,
           "an advertised tool must not return records the equivalent tool masks"

    assert [%{"src" => "[LOCAL_HOST]"}] = report.timeline
  end

  test "every read tool is masked, by construction not by convention" do
    for {tool, args} <- [
          {:get_latest_alerts, %{}},
          {:get_sensor_logs, %{}},
          {:get_jido_responses, %{}},
          {:get_case_timeline, %{case_id: "c-1"}}
        ] do
      assert {:ok, result} = Dispatch.safe_call(tool, args, opts())
      refute inspect(result) =~ "10.0.0.4", "#{tool} leaked an unmasked private address"
    end
  end

  test "a thrown term does not escape safe_call" do
    assert {:error, %{reason: "tool threw"}} =
             Dispatch.safe_call(:get_latest_alerts, %{}, query_service: Thrower)

    assert Process.alive?(self())
  end
end
