defmodule OMG.DB.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_db,
      version: OMG.Umbrella.MixProject.umbrella_version(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      env: [
        leveldb_path: Path.join([System.get_env("HOME"), ".omg/data"]),
        server_module: OMG.DB.LevelDBServer,
        server_name: OMG.DB.LevelDBServer
      ],
      extra_applications: [:logger, :appsignal],
      mod: {OMG.DB.Application, []}
    ]
  end

  defp deps do
    [
      # version caused by dependency in merkle_patricia_tree from blockchain
      {:exleveldb, "~> 0.11"},
      # TODO: we only need in :dev and :test here, but we need in :prod too in performance
      #       then there's some unexpected behavior of mix that won't allow to mix these, see
      #       [here](https://elixirforum.com/t/mix-dependency-is-not-locked-error-when-building-with-edeliver/7069/3)
      {:briefly, "~> 0.3"},
      {:appsignal, "~> 1.0"}
    ]
  end
end
