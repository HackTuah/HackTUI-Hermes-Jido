defmodule HacktuiCollab.Slack.Notification do
  @moduledoc """
  Slack outbound notification contract.
  """

  @enforce_keys [:notification_id, :destination, :kind, :subject_ref, :body, :redactable]
  defstruct [:notification_id, :destination, :kind, :subject_ref, :body, :redactable]

  @type t :: %__MODULE__{
          notification_id: String.t(),
          destination: String.t(),
          kind: atom(),
          subject_ref: String.t(),
          body: String.t(),
          redactable: boolean()
        }
end
