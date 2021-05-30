defmodule Vtc.MixProject do
  use Mix.Project

  def project do
    [
      app: :vtc,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ratio, "~> 2.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end
end
