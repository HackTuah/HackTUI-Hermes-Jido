defmodule HacktuiUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      releases: releases(),
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  # Tooling only. These back the commit gates in CLAUDE.md section 4; none ship at runtime.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # runtime: false is omitted deliberately -- in an umbrella it stops mix_audit
      # from loading its own yaml_elixir dependency, so `mix deps.audit` crashes.
      {:mix_audit, "~> 2.1", only: [:dev, :test]},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_local_path: "priv/plts",
      plt_core_path: "priv/plts",
      plt_add_apps: [:mix, :ex_unit],
      ignore_warnings: ".dialyzer_ignore.exs",
      list_unused_filters: true
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "cmd --app hacktui_core git config core.hooksPath .githooks"],
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test",
        "credo --strict",
        "deps.audit",
        "hex.audit"
      ],
      "test.all": ["test"]
    ]
  end

  def cli do
    # No preferred_envs: credo and dialyzer must run in :dev so the local hook, CI, and
    # the recorded baselines all measure the same build and PLT. Forcing :test here made
    # `mix ci` disagree with both.
    []
  end

  defp releases do
    [
      hacktui_hub: [
        applications: [
          hacktui_hub: :permanent,
          hacktui_store: :permanent,
          hacktui_tui: :permanent,
          hacktui_collab: :permanent,
          hacktui_agent: :permanent
        ]
      ],
      hacktui_sensor: [
        applications: [
          hacktui_sensor: :permanent
        ]
      ]
    ]
  end
end
