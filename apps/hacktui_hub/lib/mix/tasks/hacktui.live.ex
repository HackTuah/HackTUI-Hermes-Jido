defmodule Mix.Tasks.Hacktui.Live do
  use Mix.Task

  @shortdoc "Launch the persistent bounded live HackTUI terminal dashboard"

  def run(args) do
    Mix.Tasks.Hacktui.Tui.run(args)
  end
end
