defmodule HacktuiAgent.MCP.StdioFramingTest do
  @moduledoc """
  End-to-end framing tests against the real launcher.

  There was no test of `Stdio` at all, which is why the server shipped speaking LSP
  framing (`Content-Length` headers) rather than the MCP stdio binding. The MCP spec at
  `2024-11-05` -- the revision this server advertises -- and every revision since:

      "Messages are delimited by newlines, and MUST NOT contain embedded newlines."

  These tests drive the actual `bin/hacktui-mcp` binary with real bytes. They are tagged
  `:mcp_e2e` because they compile the umbrella on first run.
  """
  use ExUnit.Case, async: false

  @moduletag :mcp_e2e
  @moduletag timeout: 180_000

  defp repo_root, do: Path.expand("../../..", __DIR__)

  # bin/hacktui-mcp runs `mix compile` on start, in MIX_ENV=dev. The suite runs in
  # MIX_ENV=test, so warming the test build leaves dev stale and the child recompiles --
  # printing "==> app" headers onto its stdout, which looks exactly like a framing
  # violation. Warm the *dev* build explicitly.
  setup_all do
    {_out, 0} =
      System.cmd("mix", ["compile"],
        cd: repo_root(),
        env: [{"MIX_ENV", "dev"}],
        stderr_to_stdout: true
      )

    :ok
  end

  defp mcp(input) do
    path = Path.join(System.tmp_dir!(), "mcp-in-#{System.unique_integer([:positive])}")
    File.write!(path, input)

    try do
      System.cmd("sh", ["-c", "exec ./bin/hacktui-mcp < #{path} 2>/dev/null"], cd: repo_root())
    after
      File.rm(path)
    end
  end

  defp initialize_request(id) do
    Jason.encode!(%{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "initialize",
      "params" => %{
        "protocolVersion" => "2024-11-05",
        "capabilities" => %{},
        "clientInfo" => %{"name" => "framing-test", "version" => "1"}
      }
    })
  end

  test "a conformant newline-delimited request gets a response" do
    {out, 0} = mcp(initialize_request(1) <> "\n")

    assert out =~ ~s("id":1)
    assert {:ok, decoded} = out |> String.split("\n", trim: true) |> hd() |> Jason.decode()
    assert decoded["result"]["serverInfo"]["name"] == "hacktui-hermes"
  end

  test "responses are newline-delimited, not Content-Length framed" do
    {out, 0} = mcp(initialize_request(2) <> "\n")

    refute out =~ "Content-Length:",
           "MCP stdio responses must be newline-delimited JSON, not LSP-framed"

    assert String.ends_with?(out, "\n")

    # every non-empty line must be a complete JSON message on its own
    for line <- String.split(out, "\n", trim: true) do
      assert {:ok, _} = Jason.decode(line)
    end
  end

  test "legacy Content-Length input is still accepted" do
    body = initialize_request(3)
    framed = "Content-Length: #{byte_size(body)}\r\n\r\n" <> body

    {out, 0} = mcp(framed)

    assert out =~ ~s("id":3)
  end

  test "the shipped smoke client completes" do
    # bin/hacktui-mcp-smoke writes newline-delimited JSON, i.e. correct MCP framing.
    # Against the previous LSP-only reader it hung until killed. README tells users to
    # run it, so it must work.
    {out, status} =
      System.cmd(Path.join(repo_root(), "bin/hacktui-mcp-smoke"), [],
        cd: repo_root(),
        stderr_to_stdout: true
      )

    assert status == 0, "smoke client failed: #{out}"
    assert out =~ "MCP initialize ok"
  end
end
