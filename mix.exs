defmodule Hacktui.MixProject do
  use Mix.Project

  def project do
    [
      app: :hacktui,
      version: "0.1.0",
      elixir: "~> 1.19", 
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        hacktui: [include_sbom: true] 
      ]
    ]
  end

  def application do
    [
      # :crypto is added here to support OTP 28's newer cryptography features
      extra_applications: [:logger, :crypto],
      mod: {Hacktui.Application, []} 
    ]
  end

  defp deps do
    [
      {:ex_ratatui, "~> 0.4.1"},    
      {:pcap_file_ex, "~> 0.5.7"},  
      {:file_system, "~> 1.0"},     
      {:jason, "~> 1.4"}            
    ]
  end
end
