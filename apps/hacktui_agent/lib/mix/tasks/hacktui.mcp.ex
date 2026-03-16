defmodule Mix.Tasks.Hacktui.Mcp do
  use Mix.Task

  @shortdoc "Start the HackTUI MCP server over stdio"

  @impl Mix.Task
  def run(_args) do
    :logger.remove_handler(:default)
    Mix.Task.run("app.start")
    HacktuiAgent.MCP.Stdio.run()
  end
end
