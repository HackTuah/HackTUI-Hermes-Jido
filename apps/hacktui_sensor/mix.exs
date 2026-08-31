defmodule HacktuiSensor.MixProject do
  use Mix.Project

  def project do
    [
      app: :hacktui_sensor,
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
      mod: {HacktuiSensor.Application, []}
    ]
  end

  defp deps do
    [
      {:hacktui_core, in_umbrella: true},
      # Forwarder's default hub_module is HacktuiHub.Runtime. Without this the .app
      # omits hacktui_hub and the standalone release dies at boot.
      {:hacktui_hub, in_umbrella: true}
    ]
  end
end
