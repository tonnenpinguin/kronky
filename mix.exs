defmodule Kronky.Mixfile do
  use Mix.Project

  @version "0.5.0"

  def project do
    [
      app: :kronky,
      version: @version,
      elixir: "~> 1.4",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      name: "Kronky",
      source_url: "https://github.com/Ethelo/kronky",
      homepage_url: "https://github.com/Ethelo/kronky",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger], env: [field_constructor: Kronky.FieldConstructor]]
  end

  defp deps do
    [
      {:ecto, ">= 3.0.0"},
      {:absinthe, "~> 1.4"},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Utilities to return ecto validation error messages in an absinthe graphql response.
    """
  end

  defp package do
    [
      maintainers: ["Laura Ann Williams (law)", "Ethelo.com"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Ethelo/kronky",
        "HexDocs" => "https://hexdocs.pm/kronky"
      }
    ]
  end
end
