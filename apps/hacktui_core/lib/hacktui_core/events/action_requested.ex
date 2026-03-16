defmodule HacktuiCore.Events.ActionRequested do
  @moduledoc """
  Domain event emitted when an action request is created.
  """

  @enforce_keys [
    :event_id,
    :action_request_id,
    :case_id,
    :action_class,
    :target,
    :requested_at,
    :actor,
    :reason
  ]
  defstruct [
    :event_id,
    :action_request_id,
    :case_id,
    :action_class,
    :target,
    :requested_at,
    :actor,
    :reason
  ]

  @type t :: %__MODULE__{
          event_id: String.t(),
          action_request_id: String.t(),
          case_id: String.t(),
          action_class: atom(),
          target: String.t(),
          requested_at: DateTime.t(),
          actor: HacktuiCore.ActorRef.t(),
          reason: String.t()
        }
end
