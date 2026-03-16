defmodule HacktuiUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      releases: releases(),
      deps: []
    ]
  end
  

  defp aliases do
    [
      ci: ["format --check-formatted", "test"],
      "test.all": ["test"]
    ]
  end

  def cli do
    [preferred_envs: [ci: :test]]
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
