defmodule HacktuiCoreTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.{AlertLifecycle, CaseLifecycle, CommandClass}

  test "lists the bounded contexts expected by the architecture" do
    contexts = HacktuiCore.bounded_contexts()

    assert :detection_and_alerting in contexts
    assert :agent_operations in contexts
    assert :platform_operations in contexts
  end

  test "exposes shared command classes" do
    assert CommandClass.all() == [
             :observe,
             :curate,
             :notify_export,
             :change,
             :contain,
             :destructive
           ]
  end

  test "exposes alert and case lifecycle states" do
    assert :open in AlertLifecycle.states()
    assert :closed in CaseLifecycle.states()
    assert :true_positive in AlertLifecycle.dispositions()
  end
end
