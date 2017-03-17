defmodule InwxDomrobot.Mixfile do
  use Mix.Project

  def project do
    [app: :inwx_domrobot,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
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
