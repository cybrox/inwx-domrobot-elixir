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
      description: "Simple API wrapper for INWX DomRobot in Elixir",
      source_url: "https://github.com/cybrox/inwx-domrobot-elixir",
      package: package(),

      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test]
   ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Sven Gehring <cbrxde@gmail.com>"],
      links: %{github: "https://github.com/cybrox/inwx-domrobot-elixir"}
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:mojito, "~> 0.6.4"},
      {:totpex, "~> 0.1.4"},
      {:jason, "~> 1.1"},

      {:dialyzex, "~> 1.2", only: :dev, runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12.3", only: :test},
      {:mock, "~> 0.3.4", only: :test},
    ]
  end
end
