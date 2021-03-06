defmodule Mix.Tasks.Elm do
  @moduledoc """
  Invokes elm with the given args.

  Usage:

    $ mix elm TASK_OPTIONS PROFILE ELM_ARGS

  Example:

      $ mix elm default --config=elm.config.js \
        --input=css/app.css \
        --output=../priv/static/assets/app.css \
        --minify

  If elm is not installed, it is automatically downloaded.
  Note the arguments given to this task will be appended
  to any configured arguments.

  ## Options

    * `--runtime-config` - load the runtime configuration
      before executing command

  Note flags to control this Mix task must be given before the
  profile:

      $ mix elm --runtime-config default
  """

  @shortdoc "Invokes elm with the profile and args"

  use Mix.Task

  @impl true
  def run(args) do
    switches = [runtime_config: :boolean]
    {opts, remaining_args} = OptionParser.parse_head!(args, switches: switches)

    if opts[:runtime_config] do
      Mix.Task.run("app.config")
    else
      Application.ensure_all_started(:elm)
    end

    Mix.Task.reenable("elm")
    install_and_run(remaining_args)
  end

  defp install_and_run([profile | args] = all) do
    case Elm.install_and_run(String.to_atom(profile), args) do
      0 -> :ok
      status -> Mix.raise("`mix elm #{Enum.join(all, " ")}` exited with #{status}")
    end
  end

  defp install_and_run([]) do
    Mix.raise("`mix elm` expects the profile as argument")
  end
end
