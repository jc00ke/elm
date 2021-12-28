defmodule Mix.Tasks.Elm.Install do
  @moduledoc """
  Installs elm under `_build`.

  ```bash
  $ mix elm.install
  $ mix elm.install --if-missing
  ```

  By default, it installs #{Elm.latest_version()} but you
  can configure it in your config files, such as:

      config :elm, :version, "#{Elm.latest_version()}"

  ## Options

      * `--runtime-config` - load the runtime configuration
        before executing command

      * `--if-missing` - install only if the given version
        does not exist
  """

  @shortdoc "Installs elm under _build"
  use Mix.Task

  @impl true
  def run(args) do
    valid_options = [runtime_config: :boolean, if_missing: :boolean]

    case OptionParser.parse_head!(args, strict: valid_options) do
      {opts, []} ->
        if opts[:runtime_config], do: Mix.Task.run("app.config")

        if opts[:if_missing] && latest_version?() do
          :ok
        else
          Elm.install()
        end

      {_, _} ->
        Mix.raise("""
        Invalid arguments to elm.install, expected one of:

            mix elm.install
            mix elm.install --runtime-config
            mix elm.install --if-missing
        """)
    end
  end

  defp latest_version?() do
    version = Elm.configured_version()
    match?({:ok, ^version}, Elm.bin_version())
  end
end
