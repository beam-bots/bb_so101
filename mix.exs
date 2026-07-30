# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.SO101.MixProject do
  use Mix.Project

  @moduledoc """
  Beam Bots package for the SO-101 6-DOF robot arm from TheRobotStudio.
  """

  @version "0.2.2"

  def project do
    [
      aliases: aliases(),
      app: :bb_so101,
      consolidate_protocols: Mix.env() == :prod,
      deps: deps(),
      description: @moduledoc,
      dialyzer: dialyzer(),
      docs: docs(),
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix]
    ]
  end

  defp package do
    [
      maintainers: ["James Harton <james@harton.nz>"],
      licenses: ["Apache-2.0"],
      links: %{
        "Source" => "https://github.com/beam-bots/bb_so101",
        "Sponsor" => "https://github.com/sponsors/jimsynz"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "assets/logo.png",
      extras:
        ["README.md", "CHANGELOG.md"]
        |> Enum.concat(Path.wildcard("documentation/**/*.{md,livemd,cheatmd}")),
      groups_for_extras: [
        Tutorials: ~r/tutorials\//,
        "How-to Guides": ~r/how-to\//
      ],
      source_ref: "main",
      source_url: "https://github.com/beam-bots/bb_so101"
    ]
  end

  defp aliases, do: []

  defp bb_dep(default, package \\ :bb) do
    case System.get_env("BB_VERSION") do
      nil -> default
      "local" -> [path: "../#{package}", override: true]
      "main" -> [git: "https://github.com/beam-bots/#{package}.git", override: true]
      version -> "~> #{version}"
    end
  end

  defp deps do
    [
      {:bb, bb_dep("~> 0.22 and >= 0.22.3")},
      {:bb_servo_feetech, bb_dep("~> 0.3 and >= 0.3.5", :bb_servo_feetech)},
      {:feetech, bb_dep("~> 0.2", :feetech)},

      # dev/test
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.9", only: [:dev, :test], runtime: false},
      # Tracks bb_liveview's version constraint so consumers that depend on
      # both packages don't see a diverged-dependencies error.
      {:igniter, "~> 0.7 and >= 0.7.3", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
