defmodule HacktuiHub.ProposalService do
  @moduledoc """
  Minimal proposal-oriented hub service used by outer agent boundaries.
  """

  alias HacktuiHub.QueryService
  alias HacktuiStore.Repo

  @spec draft_report(String.t(), keyword()) :: map()
  def draft_report(case_id, opts \\ []) do
    query_service = Keyword.get(opts, :query_service, QueryService)
    repo = Keyword.get(opts, :repo, Repo)
    timeline = query_service.case_timeline(repo, case_id)

    %{
      case_id: case_id,
      summary: "Draft report scaffold for case #{case_id}",
      timeline: timeline
    }
  end

  @spec propose_action(map(), keyword()) :: map()
  def propose_action(action_spec, _opts \\ []) when is_map(action_spec) do
    action_spec
    |> Map.put_new(:requires_approval, true)
    |> Map.put_new(:status, :proposal)
  end
end
