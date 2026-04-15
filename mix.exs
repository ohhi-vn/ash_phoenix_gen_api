defmodule AshPhoenixGenApi.MixProject do
  use Mix.Project

  @description """
  Ash extension for generating PhoenixGenApi function configurations from Ash resources.
  """

  @version "0.1.0"

  def project do
    [
      app: :ash_phoenix_gen_api,
      version: @version,
      description: @description,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      docs: &docs/0,
      package: package(),
      source_url: "https://github.com/ohhi-vn/ash_phoenix_gen_api",
      homepage_url: "https://github.com/ohhi-vn/ash_phoenix_gen_api"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ash, ash_version("~> 3.24")},
      {:spark, "~> 2.6"},
      {:phoenix_gen_api, "~> 2.1"},
      # Dev/Test
      {:igniter, "~> 0.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test]},
      {:simple_sat, "~> 0.1", only: [:dev, :test]}
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "main" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end

  defp package do
    [
      maintainers: ["Manh Vu"],
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      links: %{
        "GitHub" => "https://github.com/ohhi-vn/ash_phoenix_gen_api",
        "PhoenixGenApi" => "https://github.com/ohhi-vn/phoenix_gen_api",
        "Ash Framework" => "https://ash-hq.org"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        {"README.md", title: "Home"},
        {"documentation/tutorials/getting-started.md", title: "Getting Started"},
        {"documentation/dsls/DSL-AshPhoenixGenApi.Resource.md",
         search_data: Spark.Docs.search_data_for(AshPhoenixGenApi.Resource)},
        {"documentation/dsls/DSL-AshPhoenixGenApi.Domain.md",
         search_data: Spark.Docs.search_data_for(AshPhoenixGenApi.Domain)}
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        Reference: ~r"documentation/dsls"
      ],
      groups_for_modules: [
        Extensions: [
          AshPhoenixGenApi.Resource,
          AshPhoenixGenApi.Domain
        ],
        Introspection: [
          AshPhoenixGenApi.Resource.Info,
          AshPhoenixGenApi.Domain.Info
        ],
        Transformers: [
          AshPhoenixGenApi.Transformers.DefineFunConfigs,
          AshPhoenixGenApi.Transformers.DefineDomainSupporter
        ],
        "Type Mapping": [
          AshPhoenixGenApi.TypeMapper
        ]
      ]
    ]
  end

  defp aliases do
    [
      docs: [
        "spark.cheat_sheets",
        "docs",
        "spark.replace_doc_links"
      ],
      "spark.formatter":
        "spark.formatter --extensions AshPhoenixGenApi.Resource,AshPhoenixGenApi.Domain",
      "spark.cheat_sheets":
        "spark.cheat_sheets --extensions AshPhoenixGenApi.Resource,AshPhoenixGenApi.Domain",
      "spark.cheat_sheets_in_search":
        "spark.cheat_sheets_in_search --extensions AshPhoenixGenApi.Resource,AshPhoenixGenApi.Domain"
    ]
  end
end
