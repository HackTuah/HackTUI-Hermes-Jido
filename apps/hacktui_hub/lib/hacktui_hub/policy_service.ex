defmodule HacktuiHub.PolicyService do
  @moduledoc """
  Shared policy-classification scaffold for hub command handling.
  """

  alias HacktuiCore.{CommandClass, Commands}

  @spec command_class(struct()) ::
          {:ok, atom()} | {:error, :unknown_command | {:invalid_command_class, atom()}}
  def command_class(command) do
    with {:ok, class} <- classify(command),
         true <- class in CommandClass.all() do
      {:ok, class}
    else
      false -> {:error, {:invalid_command_class, extract_class(command)}}
      {:error, _reason} = error -> error
    end
  end

  defp classify(%Commands.OpenCase{}), do: {:ok, :curate}
  defp classify(%Commands.TransitionAlert{}), do: {:ok, :curate}
  defp classify(%Commands.TransitionCase{}), do: {:ok, :curate}
  defp classify(%Commands.ApproveAction{}), do: {:ok, :change}
  defp classify(%Commands.RequestAction{action_class: action_class}), do: {:ok, action_class}
  defp classify(%Commands.AcceptObservation{}), do: {:ok, :observe}
  defp classify(%Commands.CreateAlert{}), do: {:ok, :observe}
  defp classify(_command), do: {:error, :unknown_command}

  defp extract_class(%Commands.RequestAction{action_class: action_class}), do: action_class
  defp extract_class(_command), do: :unknown
end
