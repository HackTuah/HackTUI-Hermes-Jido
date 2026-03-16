defmodule HacktuiCore.LifecycleTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.{AlertLifecycle, CaseLifecycle}

  test "allows valid alert transitions and rejects invalid ones" do
    assert {:ok, :acknowledged} = AlertLifecycle.transition(:open, :acknowledged)
    assert {:ok, :open} = AlertLifecycle.transition(:closed, :open)

    assert {:error, {:invalid_transition, :closed, :suppressed}} =
             AlertLifecycle.transition(:closed, :suppressed)
  end

  test "identifies terminal alert states" do
    assert AlertLifecycle.terminal?(:closed)
    refute AlertLifecycle.terminal?(:investigating)
  end

  test "allows valid case transitions and rejects invalid ones" do
    assert {:ok, :triage} = CaseLifecycle.transition(:open, :triage)
    assert {:ok, :active_investigation} = CaseLifecycle.transition(:closed, :active_investigation)

    assert {:error, {:invalid_transition, :open, :response_in_progress}} =
             CaseLifecycle.transition(:open, :response_in_progress)
  end

  test "identifies terminal case states" do
    assert CaseLifecycle.terminal?(:closed)
    refute CaseLifecycle.terminal?(:monitoring)
  end
end
