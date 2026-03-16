defmodule HacktuiCore.Commands.OpenCase do
  @moduledoc """
  Command contract for opening a case from one or more alerts.
  """

  @enforce_keys [:case_id, :title, :source_alert_ids, :actor]
  defstruct [:case_id, :title, :source_alert_ids, :actor]

  @type t :: %__MODULE__{
          case_id: String.t(),
          title: String.t(),
          source_alert_ids: [String.t()],
          actor: HacktuiCore.ActorRef.t()
        }
end
