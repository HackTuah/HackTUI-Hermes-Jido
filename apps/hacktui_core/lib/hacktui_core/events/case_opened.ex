defmodule HacktuiCore.Events.CaseOpened do
  @moduledoc """
  Domain event emitted when a case is opened.
  """

  @enforce_keys [:event_id, :case_id, :title, :source_alert_ids, :opened_at, :actor]
  defstruct [:event_id, :case_id, :title, :source_alert_ids, :opened_at, :actor]

  @type t :: %__MODULE__{
          event_id: String.t(),
          case_id: String.t(),
          title: String.t(),
          source_alert_ids: [String.t()],
          opened_at: DateTime.t(),
          actor: HacktuiCore.ActorRef.t()
        }
end
