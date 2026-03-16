defmodule HacktuiCore.CommandHandlers.Casework do
  @moduledoc """
  Pure command handling for case opening and case transitions.
  """

  alias HacktuiCore.Aggregates.InvestigationCase
  alias HacktuiCore.Commands.{OpenCase, TransitionCase}

  @spec handle(OpenCase.t(), keyword()) :: {:ok, InvestigationCase.t(), struct()}
  def handle(%OpenCase{} = command, opts), do: InvestigationCase.open(command, opts)

  @spec handle(InvestigationCase.t(), TransitionCase.t(), keyword()) ::
          {:ok, InvestigationCase.t(), struct()} | {:error, term()}
  def handle(%InvestigationCase{} = case_record, %TransitionCase{} = command, opts),
    do: InvestigationCase.transition(case_record, command, opts)
end
