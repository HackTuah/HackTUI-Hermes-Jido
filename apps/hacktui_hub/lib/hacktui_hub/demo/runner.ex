defmodule HacktuiHub.Demo.Runner do
  @moduledoc """
  Demo-critical runner for the bounded investigation workflow.
  """

  alias HacktuiCore.ActorRef
  alias HacktuiCore.Aggregates.ActionRequest, as: ActionRequestAggregate
  alias HacktuiCore.Commands.{ApproveAction, RequestAction}
  alias HacktuiHub.{Health, QueryService, Runtime}
  alias HacktuiStore.{DemoDatabase, DemoSeed, Repo}
  alias HacktuiStore.Schema.ActionRequest, as: ActionRequestRecord

  @spec investigate(String.t(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def investigate(case_id, opts \\ []) when is_binary(case_id) do
    opts = normalize_opts(opts)
    DemoDatabase.ensure_ready!()
    DemoSeed.seed_case_1!()
    ensure_runtime_started(opts)

    investigation_flow = Module.concat([HacktuiAgent, InvestigationFlow])
    hermes_local = Module.concat([HacktuiAgent, HermesLocal])

    {:ok, agent, directives} = apply(investigation_flow, :run, [case_id, opts])
    summary = apply(hermes_local, :summarize, [case_id, agent])
    artifacts = apply(hermes_local, :write_artifacts!, [summary])
    approval = ensure_simulated_action_request(case_id, summary)

    {:ok,
     %{
       case_id: case_id,
       agent: agent,
       directives: directives,
       summary: summary,
       artifacts: artifacts,
       approval: approval,
       slack_preview_data: slack_preview_data(summary, approval),
       health_snapshot: Health.status()
     }}
  end

  @spec approve(String.t(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def approve(case_id, opts \\ []) when is_binary(case_id) do
    opts = normalize_opts(opts)
    DemoDatabase.ensure_ready!()
    ensure_runtime_started(opts)

    case QueryService.pending_action_for_case(Repo, case_id) do
      nil ->
        {:error, :no_pending_action}

      %ActionRequestRecord{} = record ->
        actor =
          ActorRef.new!(
            id: "demo-approver",
            type: :human,
            role: :incident_commander,
            source: :terminal
          )

        aggregate = record_to_aggregate(record)

        {:ok, result} =
          Runtime.approve_action(
            aggregate,
            %ApproveAction{
              action_request_id: aggregate.action_request_id,
              approver: actor,
              reason: "SIMULATED approval for demo"
            },
            repo: Repo,
            event_id: "demo-approve-#{case_id}",
            approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
          )

        {:ok, %{case_id: case_id, approval: result, health_snapshot: Health.status()}}
    end
  end

  defp ensure_runtime_started(opts) do
    Application.put_env(:hacktui_store, :start_repo, true)

    if Keyword.get(opts, :enable_collab, true) do
      collab_supervisor = Module.concat([HacktuiCollab, Supervisor])
      if Process.whereis(collab_supervisor), do: Application.stop(:hacktui_collab)
      Application.put_env(:hacktui_collab, :enabled_providers, [:slack])
      {:ok, _} = Application.ensure_all_started(:hacktui_collab)
    end

    if Keyword.get(opts, :enable_agent, true) do
      agent_supervisor = Module.concat([HacktuiAgent, Supervisor])
      if Process.whereis(agent_supervisor), do: Application.stop(:hacktui_agent)
      Application.put_env(:hacktui_agent, :enabled_backends, [:jido])
      {:ok, _} = Application.ensure_all_started(:hacktui_agent)
    end

    {:ok, _} = Application.ensure_all_started(:hacktui_hub)
    {:ok, _} = Application.ensure_all_started(:hacktui_tui)
    :ok
  end

  defp ensure_simulated_action_request(case_id, summary) do
    case QueryService.pending_action_for_case(Repo, case_id) do
      %ActionRequestRecord{} = existing ->
        existing

      nil ->
        actor =
          ActorRef.new!(id: "demo-operator", type: :human, role: :analyst, source: :terminal)

        {:ok, result} =
          Runtime.request_action(
            %RequestAction{
              action_request_id: "sim-#{case_id}-contain",
              case_id: case_id,
              action_class: :contain,
              target: "host-42",
              requested_by: actor,
              reason: "SIMULATED: #{summary.recommendation}"
            },
            repo: Repo,
            event_id: "demo-request-#{case_id}",
            requested_at: DateTime.utc_now() |> DateTime.truncate(:second)
          )

        result.aggregate
    end
  end

  defp record_to_aggregate(%ActionRequestRecord{} = record) do
    %ActionRequestAggregate{
      action_request_id: record.action_request_id,
      case_id: record.case_id,
      action_class: String.to_atom(record.action_class),
      target: record.target,
      approval_status: String.to_atom(record.approval_status),
      requested_by:
        ActorRef.new!(
          id: record.requested_by || "unknown",
          type: :human,
          role: :analyst,
          source: :terminal
        ),
      approved_by:
        if(record.approved_by,
          do:
            ActorRef.new!(
              id: record.approved_by,
              type: :human,
              role: :incident_commander,
              source: :terminal
            ),
          else: nil
        ),
      reason: record.reason || "",
      inserted_at: record.inserted_at,
      updated_at: record.updated_at,
      approved_at: record.approved_at
    }
  end

  defp slack_preview_data(summary, approval) do
    %{
      notification_id: "demo-#{summary.case_id}",
      destination: "slack:#soc-demo-preview",
      kind: :case_update,
      subject_ref: summary.case_id,
      body:
        "#{summary.summary} | Recommendation: #{summary.recommendation} | Pending action: #{approval.action_request_id}",
      redactable: true
    }
  end

  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
end
