defmodule HacktuiCollab.Slack.CommandRequest do
  @moduledoc """
  Slack inbound command contract.
  """

  @enforce_keys [:request_id, :slack_user_id, :command, :text, :channel_id, :received_at]
  defstruct [:request_id, :slack_user_id, :command, :text, :channel_id, :received_at]

  @type t :: %__MODULE__{
          request_id: String.t(),
          slack_user_id: String.t(),
          command: String.t(),
          text: String.t(),
          channel_id: String.t(),
          received_at: DateTime.t()
        }
end
