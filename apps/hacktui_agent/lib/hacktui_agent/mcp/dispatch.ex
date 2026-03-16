defmodule HacktuiAgent.MCP.Dispatch do
  @moduledoc """
  Minimal MCP dispatch layer wired onto hub query and proposal services.
  """

  alias HacktuiHub.{ProposalService, QueryService}
  alias HacktuiStore.Repo

  @spec call(atom(), map(), keyword()) ::
          {:ok, term()}
          | {:error, :unknown_tool | :missing_case_id | :sensor_log_query_unavailable}
  def call(:get_latest_alerts, _args, opts) do
    query_service = Keyword.get(opts, :query_service, QueryService)
    {:ok, query_service.alert_queue()}
  end

  def call(:get_sensor_logs, _args, opts) do
    query_service = Keyword.get(opts, :query_service, QueryService)
    repo = Keyword.get(opts, :repo, Repo)
    {:ok, query_service.sensor_logs(repo)}
  end

  def call(:get_jido_responses, _args, opts) do
    query_service = Keyword.get(opts, :query_service, QueryService)
    repo = Keyword.get(opts, :repo, Repo)
    {:ok, query_service.jido_responses(repo)}
  end

  def call(:get_case_timeline, %{"case_id" => case_id}, opts),
    do: call(:get_case_timeline, %{case_id: case_id}, opts)

  def call(:get_case_timeline, %{case_id: case_id}, opts) when is_binary(case_id) do
    query_service = Keyword.get(opts, :query_service, QueryService)
    repo = Keyword.get(opts, :repo, Repo)
    {:ok, query_service.case_timeline(repo, case_id)}
  end

  def call(:get_case_timeline, _args, _opts), do: {:error, :missing_case_id}

  def call(:draft_report, %{"case_id" => case_id}, opts),
    do: call(:draft_report, %{case_id: case_id}, opts)

  def call(:draft_report, %{case_id: case_id}, opts) when is_binary(case_id) do
    proposal_service = Keyword.get(opts, :proposal_service, ProposalService)
    {:ok, proposal_service.draft_report(case_id, opts)}
  end

  def call(:draft_report, _args, _opts), do: {:error, :missing_case_id}

  def call(:propose_action, action_spec, opts) when is_map(action_spec) do
    proposal_service = Keyword.get(opts, :proposal_service, ProposalService)
    {:ok, proposal_service.propose_action(action_spec, opts)}
  end

  def call(_tool, _args, _opts), do: {:error, :unknown_tool}
end
