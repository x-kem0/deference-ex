defmodule Deference.MixProject do
  use Mix.Project

  def project do
    [
      app: :deference,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Deference",
      description: "A module for deferring cleanup functions in error cases",
      source_url: "https://github.com/x-kem0/deference-ex"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end
end
