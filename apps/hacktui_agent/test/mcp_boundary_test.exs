defmodule HacktuiAgent.MCP.BoundaryTest do
  @moduledoc """
  The MCP boundary must enforce the contract it advertises.

  The JSON Schemas at `Server.input_schema/1` were used only to build `tools/list`.
  Because `normalize_arguments/1` also retained unrecognised string keys, and
  `ProposalService` set its safety fields with atom keys via `Map.put_new`, a caller
  could smuggle `requires_approval`/`status` past both and win the collision when
  `to_json_value/1` stringified them.
  """
  use ExUnit.Case, async: true

  alias HacktuiAgent.MCP.{Egress, Schema, Server}

  describe "schema validation" do
    test "rejects properties the schema does not declare" do
      assert {:error, reason} =
               Schema.validate(
                 %{
                   "case_id" => "c-1",
                   "action_class" => "contain",
                   "target" => "h1",
                   "requires_approval" => false,
                   "status" => "approved"
                 },
                 Server.input_schema_for(:propose_action)
               )

      assert reason =~ "unknown properties"
      assert reason =~ "requires_approval"
      assert reason =~ "status"
    end

    test "accepts a well-formed proposal" do
      assert :ok =
               Schema.validate(
                 %{"case_id" => "c-1", "action_class" => "contain", "target" => "h1"},
                 Server.input_schema_for(:propose_action)
               )
    end

    test "enforces required properties" do
      assert {:error, reason} =
               Schema.validate(%{"case_id" => "c-1"}, Server.input_schema_for(:propose_action))

      assert reason =~ "missing required"
    end

    test "enforces the advertised numeric range" do
      schema = Server.input_schema_for(:get_latest_alerts)

      assert :ok = Schema.validate(%{"limit" => 10}, schema)
      assert {:error, reason} = Schema.validate(%{"limit" => 500}, schema)
      assert reason =~ "<= 100"
      assert {:error, _} = Schema.validate(%{"limit" => 0}, schema)
    end

    test "enforces declared types" do
      assert {:error, reason} =
               Schema.validate(%{"limit" => "ten"}, Server.input_schema_for(:get_latest_alerts))

      assert reason =~ "integer"
    end
  end

  describe "egress masking" do
    test "masks identity-bearing fields in nested results" do
      masked =
        Egress.mask([
          %{kind: "network.flow", payload: %{"src" => "10.0.0.4", "site" => "192.168.1.1"}}
        ])

      assert [%{payload: %{"src" => "[LOCAL_HOST]", "site" => "[LOCAL_HOST]"}}] = masked
    end

    test "leaves non-identity fields untouched" do
      assert [%{kind: "network.flow"}] = Egress.mask([%{kind: "network.flow"}])
    end

    test "handles structs and bare values" do
      assert Egress.mask("plain") == "plain"
      assert Egress.mask(nil) == nil
      assert Egress.mask(%{}) == %{}
    end
  end
end
