defmodule HacktuiStore.RepoBehaviour do
  @moduledoc """
  The subset of `Ecto.Repo` that the hub actually depends on.

  Before this, `repo` was injected as an untyped `module()` throughout `HacktuiHub`, so a
  test double could drift from the real repo with no compiler check. That is not
  hypothetical: three tests failed for exactly that reason — `FakeTransactionRepo` never
  implemented `get_by/2`, which `Runtime.persist_alert_correlation_metadata/7` has called
  since it was written.

  Declaring `@behaviour HacktuiStore.RepoBehaviour` on a double turns that class of drift
  into a compile-time warning instead of a runtime `UndefinedFunctionError` discovered
  months later.

  It is also the seam an external consumer needs: `use HacktuiStore, repo: MyApp.Repo`
  becomes expressible once the contract is named.
  """

  @type queryable :: Ecto.Queryable.t()

  @callback all(queryable()) :: [struct() | map() | term()]
  @callback one(queryable()) :: struct() | map() | nil
  @callback get_by(module(), keyword()) :: struct() | nil
  @callback transaction(Ecto.Multi.t() | (-> any())) ::
              {:ok, map()} | {:error, any()} | {:error, atom(), any(), map()}
  @callback update(Ecto.Changeset.t()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback insert_all(module(), list(), keyword()) :: {non_neg_integer(), nil | [term()]}
  @callback delete_all(queryable()) :: {non_neg_integer(), nil | [term()]}

  # `Ecto.Repo` supplies all of these, so the real repo satisfies the behaviour without
  # declaring it. Doubles must declare it.
  @optional_callbacks one: 1, insert_all: 3, delete_all: 1
end
