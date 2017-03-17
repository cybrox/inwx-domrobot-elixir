defmodule InwxDomrobot.Mixfile do
  use Mix.Project

  def project do
    [
      app: :inwx_domrobot,
      version: "0.1.0",
      elixir: "~> 1.4",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),

      name: "INWX DomRobot",
      description: "Simple interface for INWX DomRobot in Elixir",
      source_url: "https://github.com/cybrox/inwx-domrobot",
      package: package()
   ]
  end


  # Package
  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Sven Gehring <cbrxde@gmail.com>"],
      links: %{github: "https://github.com/cybrox/inwx-domrobot"}
    ]
  end


  # Application
  def application do
    [extra_applications: [:logger]]
  end


  # Dependencies 
  defp deps do
    [
      {:httpoison, "~> 0.10.0"},
      
      {:erlsom, github: "willemdj/erlsom"},
      {:xmlrpc, "~> 0.1"}
    ]
  end
end
