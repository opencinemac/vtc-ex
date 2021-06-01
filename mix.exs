defmodule Vtc.MixProject do
  use Mix.Project

  def project do
    [
      app: :vtc,
      version: "0.1.7",
      description: "A SMPTE timecode library for Elixir",
      source_url: "https://github.com/opencinemac/vtc-ex",
      elixir: "~> 1.12",
      test_coverage: [tool: :covertool],
      docs: [
        # The main page in the docs
        main: "readme",
        logo: "zdocs/source/logo1.svg",
        extras: ["README.md", "zdocs/history.md"]
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ratio, "~> 2.0"},
      {:decimal, "~> 2.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:covertool, "~> 2.0", only: [:test]},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "vtc",
      # These are the default files included in the package
      files: ~w(lib mix.exs README.md* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/opencinemac/vtc-ex"}
    ]
  end
end
