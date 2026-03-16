defmodule Mix.Tasks.Demo.Approve do
  use Mix.Task

  @shortdoc "Approve the simulated pending demo action for a case"

  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [case_id | _rest] ->
        case HacktuiHub.Demo.Runner.approve(case_id) do
          {:ok, result} ->
            Mix.shell().info("Approved simulated action for #{case_id}")
            Mix.shell().info(inspect(result.approval.aggregate, pretty: true))
            Mix.shell().info("Health: #{inspect(result.health_snapshot, pretty: true)}")

          {:error, :no_pending_action} ->
            Mix.raise("no pending simulated action for #{case_id}")
        end

      _ ->
        Mix.raise("usage: mix demo.approve case-1")
    end
  end
end
