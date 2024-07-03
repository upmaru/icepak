defmodule Icepak.MixProject do
  use Mix.Project

  def project do
    [
      app: :icepak,
      version: "1.0.3",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      dialyzer: dialyzer(),
      escript: [
        main_module: Icepak.CLI
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Icepak.Application, []}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/fixture"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5.0"},
      {:finch, "~> 0.18.0"},
      {:jason, "~> 1.0"},
      {:castore, "~> 1.0"},
      {:aws, "~> 0.13.0"},
      {:lexdee, "~> 2.4"},
      {:uniq, "~> 0.6"},
      {:shortuuid, "~> 3.0"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:mox, "~> 1.1.0", only: :test}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  def package do
    [
      description: "Image management tool for Polar",
      files: ["lib", "config", "mix.exs", "README.md"],
      maintainers: ["Zack Siri"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/upmaru/icepak"}
    ]
  end
end
