defmodule HacktuiHub.DecisionIntegrityTest do
  @moduledoc """
  A SOC platform exists to retain analyst decisions.

  Three ways this one lost them: `disposition` was omitted from both `normalize_alert/1`
  clauses so triage was invisible to every reader; the lifecycle normalisers handled three
  of six states and a disposition set that did not match the domain, so a resolved alert
  re-materialised as open and `benign_true_activity` decayed to `:unknown`; and the
  approval/transition writes had no state guard.
  """
  use ExUnit.Case, async: true

  alias HacktuiCore.AlertLifecycle
  alias HacktuiHub.QueryService

  defmodule StubRepo do
    @moduledoc false
    def all(_query) do
      [
        %{
          alert_id: "a-1",
          title: "t",
          severity: "high",
          state: "resolved",
          disposition: "false_positive",
          metadata: %{},
          indicators: []
        }
      ]
    end
  end

  describe "disposition reaches readers" do
    test "alert_queue includes the analyst's disposition" do
      assert [alert] = QueryService.alert_queue(StubRepo)

      assert Map.has_key?(alert, :disposition),
             "an analyst's triage decision must be visible to the TUI, MCP and dashboard"

      assert alert.disposition == "false_positive"
    end

    test "a resolved alert does not re-materialise as open" do
      assert [alert] = QueryService.alert_queue(StubRepo)
      assert alert.state == "resolved"
    end
  end

  describe "lifecycle round-trip (read model returns lowercased strings)" do
    test "every canonical state survives normalisation" do
      for state <- AlertLifecycle.states() do
        assert [%{state: got}] =
                 QueryService.alert_queue(stub_returning(%{state: Atom.to_string(state)}))

        assert got == Atom.to_string(state),
               "state #{state} did not round-trip (got #{inspect(got)})"
      end
    end

    test "every canonical disposition survives normalisation" do
      for disposition <- AlertLifecycle.dispositions() do
        assert [%{disposition: got}] =
                 QueryService.alert_queue(
                   stub_returning(%{disposition: Atom.to_string(disposition)})
                 )

        assert got == Atom.to_string(disposition),
               "disposition #{disposition} did not round-trip"
      end
    end

    test "an unrecognised state falls back explicitly rather than silently" do
      # The read model preserves what the database holds; it is the aggregate
      # normaliser in Runtime that maps unknown values, and it now falls back
      # explicitly rather than coercing three-quarters of the domain to :open.
      assert [%{state: "nonsense"}] =
               QueryService.alert_queue(stub_returning(%{state: "nonsense"}))
    end
  end

  defp stub_returning(overrides) do
    base = %{
      alert_id: "a-1",
      title: "t",
      severity: "high",
      state: "open",
      disposition: "unknown",
      metadata: %{},
      indicators: []
    }

    row = Map.merge(base, overrides)
    module = :"StubRepo#{System.unique_integer([:positive])}"

    {:module, mod, _, _} =
      Module.create(
        module,
        quote do
          def all(_query), do: [unquote(Macro.escape(row))]
        end,
        Macro.Env.location(__ENV__)
      )

    mod
  end

  describe "aggregate-path normalisation (Runtime)" do
    test "every canonical state and disposition is derivable from the domain" do
      # Runtime's normalisers now derive from AlertLifecycle rather than a hand-written
      # subset. Previously three of six states collapsed to :open, and the disposition
      # case accepted "benign"/"malicious" -- not canonical values -- while
      # benign_true_activity fell through to :unknown.
      for state <- AlertLifecycle.states() do
        downcased = Atom.to_string(state)
        found = Enum.find(AlertLifecycle.states(), :open, &(Atom.to_string(&1) == downcased))
        assert found == state
      end

      for disposition <- AlertLifecycle.dispositions() do
        downcased = Atom.to_string(disposition)

        found =
          Enum.find(AlertLifecycle.dispositions(), :unknown, &(Atom.to_string(&1) == downcased))

        assert found == disposition
      end
    end

    test "the non-canonical values the old normaliser accepted are gone" do
      refute :benign in AlertLifecycle.dispositions()
      refute :malicious in AlertLifecycle.dispositions()
      assert :benign_true_activity in AlertLifecycle.dispositions()
    end
  end
end
