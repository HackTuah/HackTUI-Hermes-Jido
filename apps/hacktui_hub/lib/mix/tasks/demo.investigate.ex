defmodule Mix.Tasks.Demo.Investigate do
  use Mix.Task

  @shortdoc "Run the bounded demo investigation for a case"

  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [case_id | _rest] ->
        {:ok, result} = HacktuiHub.Demo.Runner.investigate(case_id)

        demo_view = Module.concat([HacktuiTui, DemoTerminalView])

        view =
          apply(demo_view, :render, [
            %{
              case_id: result.case_id,
              investigation_status: result.agent.state.status,
              matched_alert_ids: result.summary.matched_alert_ids,
              shared_indicators: result.summary.shared_indicators,
              summary: result.summary.summary,
              recommendation: result.summary.recommendation,
              health_snapshot: result.health_snapshot
            }
          ])

        Mix.shell().info(view)
        notification_mod = Module.concat([HacktuiCollab, Slack, Notification])
        renderer_mod = Module.concat([HacktuiCollab, Slack, Renderer])
        notification = struct!(notification_mod, result.slack_preview_data)
        slack_preview = apply(renderer_mod, :render, [notification])
        Mix.shell().info("Slack preview: #{inspect(slack_preview, pretty: true)}")
        Mix.shell().info("Artifacts: #{inspect(result.artifacts, pretty: true)}")
        Mix.shell().info("Pending simulated approval: mix demo.approve #{case_id}")

      _ ->
        Mix.raise("usage: mix demo.investigate case-1")
    end
  end
end
