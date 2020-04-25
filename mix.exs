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
      source_url: "https://github.com/cybrox/inwx-domrobot-elixir",
      package: package()
   ]
  end


  # Package
  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Sven Gehring <cbrxde@gmail.com>"],
      links: %{github: "https://github.com/cybrox/inwx-domrobot-elixir"}
    ]
  end


  # Application
  def application do
    [extra_applications: [:logger]]
  end


  # Dependencies 
  defp deps do
    [
      {:httpoison, "~> 1.6.2"},
      {:xmlrpc, "~> 1.1"},

      # Development dependencies
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end
end
