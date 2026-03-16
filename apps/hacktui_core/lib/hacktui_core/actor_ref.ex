defmodule HacktuiCore.ActorRef do
  @moduledoc """
  Stable actor reference used across commands, events, and audit records.
  """

  @enforce_keys [:id, :type, :role, :source]
  defstruct [:id, :type, :role, :source]

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          role: atom(),
          source: atom()
        }

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, :invalid_actor_ref}
  def new(attrs) when is_list(attrs), do: attrs |> Enum.into(%{}) |> new()

  def new(%{} = attrs) do
    with {:ok, id} when is_binary(id) <- fetch(attrs, :id),
         {:ok, type} when is_atom(type) <- fetch(attrs, :type),
         {:ok, role} when is_atom(role) <- fetch(attrs, :role),
         {:ok, source} when is_atom(source) <- fetch(attrs, :source) do
      {:ok, %__MODULE__{id: id, type: type, role: role, source: source}}
    else
      _ -> {:error, :invalid_actor_ref}
    end
  end

  @spec new!(keyword() | map()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, actor} -> actor
      {:error, reason} -> raise ArgumentError, "invalid actor ref: #{inspect(reason)}"
    end
  end

  defp fetch(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_key, key}}
    end
  end
end
