defmodule HacktuiStore.MixProject do
  use Mix.Project

  def project do
    [
      app: :hacktui_store,
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
      mod: {HacktuiStore.Application, []}
    ]
  end

  defp deps do
    [
      {:hacktui_core, in_umbrella: true},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.19"},
      {:jason, "~> 1.4"}
    ]
  end
end
