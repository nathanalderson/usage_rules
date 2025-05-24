defmodule UsageRules.MixProject do
  use Mix.Project

  def project do
    [
      app: :usage_rules,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:igniter, path: "../../ash/igniter", optional: true, runtime: false}
    ]
  end
end
