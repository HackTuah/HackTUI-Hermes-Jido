defmodule Hacktui.MixProject do
  use Mix.Project

  def project do
    [
      app: :hacktui,
      version: "0.1.0",
      elixir: "~> 1.19", 
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [
        hacktui: [include_sbom: true] 
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Hacktui.Application, []} 
    ]
  end

  defp deps do
    [
      {:ex_ratatui, "~> 0.4.1"},    
      {:pcap_file_ex, "~> 0.5.7"},  
      {:file_system, "~> 1.0"},     
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.11"}, 
      {:postgrex, "~> 0.19"},
      {:logger_file_backend, "~> 0.0.13"},
      {:req, "~> 0.4.0"},
      {:hermes_mcp, "~> 0.3.0"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
