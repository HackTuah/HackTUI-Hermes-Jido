defmodule Mix.Tasks.Demo.View do
  use Mix.Task

  @shortdoc "Render the bounded terminal view for a seeded case"

  alias HacktuiHub.QueryService
  alias HacktuiStore.Repo

  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [case_id | _rest] ->
        {:ok, result} = HacktuiHub.Demo.Runner.investigate(case_id)

        demo_view = Module.concat([HacktuiTui, DemoTerminalView])

        Mix.shell().info(
          apply(demo_view, :render, [
            %{
              case_id: result.case_id,
              investigation_status: result.agent.state.status,
              matched_alert_ids: result.summary.matched_alert_ids,
              shared_indicators: result.summary.shared_indicators,
              summary: result.summary.summary,
              recommendation: result.summary.recommendation,
              health_snapshot: result.health_snapshot,
              latest_alerts: QueryService.alert_queue(Repo) |> Enum.take(3),
              active_cases: QueryService.case_board(Repo) |> Enum.take(3),
              pending_approvals: QueryService.approval_inbox(Repo) |> Enum.take(3),
              latest_observations: QueryService.latest_observations(Repo, limit: 3)
            }
          ])
        )

      _ ->
        Mix.raise("usage: mix demo.view case-1")
    end
  end
end
