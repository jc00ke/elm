defmodule Elm.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jc00ke/elm"

  def project do
    [
      app: :elm,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Mix tasks for installing and invoking elm",
      package: %{
        links: %{
          "GitHub" => @source_url,
          "Elm" => "https://elm-lang.org"
        },
        licenses: ["MIT"]
      },
      docs: [
        main: "Elm",
        source_url: @source_url,
        source_ref: "v#{@version}",
        extras: ["CHANGELOG.md"]
      ],
      xref: [
        exclude: [:httpc, :public_key]
      ],
      aliases: [
        test: ["elm.install --if-missing", "test"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Elm, []},
      env: [default: []]
    ]
  end

  defp deps do
    [
      {:castore, ">= 0.0.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :docs}
    ]
  end
end
