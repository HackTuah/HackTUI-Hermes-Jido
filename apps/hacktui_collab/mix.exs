defmodule HacktuiCollab.MixProject do
  use Mix.Project

  def project do
    [
      app: :hacktui_collab,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {HacktuiCollab.Application, []}
    ]
  end

  defp deps do
    [
      {:hacktui_core, in_umbrella: true},
      {:hacktui_hub, in_umbrella: true}
    ]
  end
end
