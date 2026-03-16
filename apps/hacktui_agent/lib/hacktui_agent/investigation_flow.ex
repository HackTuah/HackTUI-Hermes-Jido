defmodule HacktuiAgent.InvestigationFlow do
  @moduledoc """
  Runs the first bounded Jido-powered investigation and correlation flow.
  """

  alias HacktuiAgent.Agents.InvestigationCoordinator
  alias HacktuiAgent.Actions.Investigation.{CorrelateContext, DraftReport, EmitCompletion}
  alias HacktuiHub.QueryService
  alias HacktuiStore.Repo

  @type options :: nil | keyword() | map()

  @spec run(String.t()) :: {:ok, Jido.Agent.t(), [struct()]} | {:error, term()}
  def run(case_id) when is_binary(case_id), do: run(case_id, nil)

  @spec run(String.t(), options()) :: {:ok, Jido.Agent.t(), [struct()]} | {:error, term()}
  def run(case_id, opts) when is_binary(case_id) do
    opts = normalize_opts(opts)
    query_service = Keyword.get(opts, :query_service, QueryService)
    repo = Keyword.get(opts, :repo, Repo)

    context =
      case Code.ensure_loaded(query_service) do
        {:module, _loaded} ->
          if function_exported?(query_service, :investigation_context, 2) do
            query_service.investigation_context(repo, case_id)
          else
            %{
              alerts: query_service.alert_queue(repo),
              timeline: query_service.case_timeline(repo, case_id)
            }
          end

        _other ->
          %{
            alerts: query_service.alert_queue(repo),
            timeline: query_service.case_timeline(repo, case_id)
          }
      end

    agent =
      InvestigationCoordinator.new(
        id: "investigation-#{case_id}",
        state: %{status: :queued, case_id: case_id, context: context}
      )

    {updated_agent, directives} =
      InvestigationCoordinator.cmd(agent, [CorrelateContext, DraftReport, EmitCompletion])

    {:ok, updated_agent, directives}
  end

  defp normalize_opts(nil), do: []
  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)

  defp normalize_opts(opts) do
    raise ArgumentError,
          "expected InvestigationFlow options to be nil, a keyword list, or a map, got: #{inspect(opts)}"
  end
end
