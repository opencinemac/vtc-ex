defmodule Vtc.MixProject do
  use Mix.Project

  alias Vtc.Source.Frames
  alias Vtc.Source.Seconds

  def project do
    [
      app: :vtc,
      version: "0.2.0",
      description: "A SMPTE timecode library for Elixir",
      source_url: "https://github.com/opencinemac/vtc-ex",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: :covertool],
      docs: [
        # The main page in the docs
        main: "readme",
        logo: "zdocs/source/logo1.svg",
        extras: [
          "README.md",
          "zdocs/quickstart.cheatmd",
          "zdocs/history.md",
          "zdocs/framerate_vs_timebase.md",
          "zdocs/the_rational_rationale.md",
          "CONTRIBUTING.md"
        ],
        groups_for_modules: [
          "Core API": [Vtc.Timecode, Vtc.Framerate, Vtc.Range],
          Data: [Vtc.Timecode.Sections, Vtc.Rates, Vtc.FilmFormat],
          "Frames Formats": [Frames.FeetAndFrames, Frames.TimecodeStr],
          "Seconds Formats": [Seconds.PremiereTicks, Seconds.RuntimeStr],
          "Source Protocols": [Seconds, Frames],
          "Ecto Types": [Vtc.Ecto.Postgres.PgRational, Vtc.Ecto.Postgres.PgRational.Migrations],
          "Test Utilities": [Vtc.TestUtls.StreamDataVtc]
        ],
        groups_for_docs: [
          Parse: &(&1[:section] == :parse),
          Manipulate: &(&1[:section] == :manipulate),
          Inspect: &(&1[:section] == :inspect),
          Compare: &(&1[:section] == :compare),
          Arithmetic: &(&1[:section] == :arithmetic),
          Convert: &(&1[:section] == :convert),
          Consts: &(&1[:section] == :consts),
          Perfs: &(&1[:section] == :perfs),
          Queries: &(&1[:section] == :ecto_queries),
          Full: &(&1[:section] == :migrations_full),
          PgConstraints: &(&1[:section] == :migrations_constraints),
          PgTypes: &(&1[:section] == :migrations_types),
          PgFunctions: &(&1[:section] == :migrations_functions)
        ]
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      dialyzer: [plt_add_apps: Enum.map(deps(), &elem(&1, 0))]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application, do: []

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    include_postgrex? = not (:vtc |> Application.get_env(Postgres, []) |> Keyword.get(:include?, false))

    [
      # Library Dependencies
      {:decimal, "~> 2.0"},
      {:ratio, "~> 3.0"},
      {:ecto, "~> 3.10", optional: include_postgrex?},
      {:ecto_sql, "~> 3.10", optional: include_postgrex?},
      {:postgrex, ">= 0.0.0", optional: include_postgrex?},

      # Test dependencies
      {:covertool, "~> 2.0", only: [:test]},
      {:stream_data, "~> 0.5.0", only: [:dev, :test]},
      {:junit_formatter, "~> 3.1", only: [:test]},

      # Dev dependencies
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.27", only: [:dev, :test], runtime: false},
      {:styler, "~> 0.7", only: [:dev, :test], runtime: false},
      {:examples_styler, "~> 0.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
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
