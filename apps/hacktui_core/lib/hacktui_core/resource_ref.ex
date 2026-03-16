defmodule HacktuiCore.ResourceRef do
  @moduledoc """
  Stable resource reference used for cross-boundary identifiers.
  """

  @enforce_keys [:kind, :id, :scope]
  defstruct [:kind, :id, :scope]

  @type t :: %__MODULE__{
          kind: atom(),
          id: String.t(),
          scope: atom()
        }

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, :invalid_resource_ref}
  def new(attrs) when is_list(attrs), do: attrs |> Enum.into(%{}) |> new()

  def new(%{} = attrs) do
    with {:ok, kind} when is_atom(kind) <- fetch(attrs, :kind),
         {:ok, id} when is_binary(id) <- fetch(attrs, :id),
         {:ok, scope} when is_atom(scope) <- fetch(attrs, :scope) do
      {:ok, %__MODULE__{kind: kind, id: id, scope: scope}}
    else
      _ -> {:error, :invalid_resource_ref}
    end
  end

  @spec new!(keyword() | map()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, ref} -> ref
      {:error, reason} -> raise ArgumentError, "invalid resource ref: #{inspect(reason)}"
    end
  end

  defp fetch(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_key, key}}
    end
  end
end
