defmodule Elm do
  # https://github.com/elm/compiler/releases/
  @latest_version "0.19.1"

  @moduledoc """
  Elm is an installer and runner for [Elm](https://elm-lang.org).

  ## Profiles

  You can define multiple Elm profiles. By default, there is a
  profile called `:default` which you can configure its args, current
  directory and environment:

      config :elm,
        version: "#{@latest_version}",
        default: [
          args: ~w(
            make
            src/Main.elm
            --optimize
            --output=../priv/static/assets/elm.js
          ),
          cd: Path.expand("../assets", __DIR__),
        ]

  ## Elm configuration

  There are two global configurations for the elm application:

    * `:version` - the expected elm version

    * `:path` - the path to find the elm executable at. By
      default, it is automatically downloaded and placed inside
      the `_build` directory of your current app

  Overriding the `:path` is not recommended, as we will automatically
  download and manage `elm` for you. But in case you can't download
  it (for example, GitHub behind a proxy), you may want to
  set the `:path` to a configurable system location.

    For instance, you can install `elm` globally by following
    the [install steps](https://guide.elm-lang.org/install/elm.html).

  Once you find the location of the executable, you can store it in a
  `MIX_ELM_PATH` environment variable, which you can then read in
  your configuration file:

      config :elm, path: System.get_env("MIX_ELM_PATH")

  The first time this package is installed, a default elm configuration
  will be placed in a new `assets/elm/elm.json` file. See
  the [Elm documentation](https://elmprogramming.com/elm-install.html)
  on configuration options.
  """

  use Application
  require Logger

  @doc false
  def start(_, _) do
    unless Application.get_env(:elm, :version) do
      Logger.warn("""
      elm version is not configured. Please set it in your config files:

          config :elm, :version, "#{latest_version()}"
      """)
    end

    configured_version = configured_version()

    case bin_version() do
      {:ok, ^configured_version} ->
        :ok

      {:ok, version} ->
        Logger.warn("""
        Outdated elm version. Expected #{configured_version}, got #{version}. \
        Please run `mix elm.install` or update the version in your config files.\
        """)

      :error ->
        :ok
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end

  @doc false
  # Latest known version at the time of publishing.
  def latest_version, do: @latest_version

  @doc """
  Returns the configured elm version.
  """
  def configured_version do
    Application.get_env(:elm, :version, latest_version())
  end

  @doc """
  Returns the configuration for the given profile.

  Returns nil if the profile does not exist.
  """
  def config_for!(profile) when is_atom(profile) do
    Application.get_env(:elm, profile) ||
      raise ArgumentError, """
      unknown elm profile. Make sure the profile is defined in your config/config.exs file, such as:

          config :elm,
            version: "#{@latest_version}",
            #{profile}: [
              args: ~w(
                make
                src/Main.elm
                --optimize
                --output=../priv/static/assets/elm.js
              ),
              cd: Path.expand("../assets/elm", __DIR__)
            ]
      """
  end

  @doc """
  Returns the path to the executable.

  The executable may not be available if it was not yet installed.
  """
  def bin_path do
    name = "elm"

    Application.get_env(:elm, :path) ||
      if Code.ensure_loaded?(Mix.Project) do
        Path.join(Path.dirname(Mix.Project.build_path()), name)
      else
        Path.expand("_build/#{name}")
      end
  end

  @doc """
  Returns the version of the elm executable.

  Returns `{:ok, version_string}` on success or `:error` when the executable
  is not available.
  """
  def bin_version do
    path = bin_path()

    with true <- File.exists?(path),
         {out, 0} <- System.cmd(path, ["--version"]) do
      {:ok, String.trim(out)}
    else
      _ -> :error
    end
  end

  defp prepare_args(args, config) do
    src_files = args[:src_files] || config[:src_files] || "src/*.elm"
    output = config[:output] || args[:output] || raise "must set :output option"
    output = "--output=#{output}"

    if args[:optimize] && args[:debug],
      do: raise("can't optimize & debug at the same time")

    debug_or_optimize_flag =
      cond do
        args[:optimize] -> "--optimize"
        args[:debug] -> "--debug"
        true -> nil
      end

    [src_files, debug_or_optimize_flag, output]
  end

  @doc """
  Runs the given command with `args`.

  The given args will be appended to the configured args.
  The task output will be streamed directly to stdio. It
  returns the status of the underlying call.
  """
  def run(profile, extra_args) when is_atom(profile) and is_list(extra_args) do
    config = config_for!(profile)

    args =
      (extra_args -- (config[:args] || []))
      |> prepare_args(config)
      |> Enum.join(" ")

    opts = [
      cd: config[:cd] || File.cwd!(),
      env: config[:env] || %{},
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    ]

    "#{bin_path()} make #{args}"
    |> System.shell(opts)
    |> elem(1)
  end

  @doc false
  def script_path() do
    Path.join(:code.priv_dir(:elm), "elm.bash")
  end

  @doc """
  Installs, if not available, and then runs `elm`.

  Returns the same as `run/2`.
  """
  def install_and_run(profile, args) do
    unless File.exists?(bin_path()) do
      install()
    end

    run(profile, args)
  end

  @doc """
  Installs elm with `configured_version/0`.
  """
  def install do
    version = configured_version()
    name = "binary-for-#{target()}-64-bit.gz"
    url = "https://github.com/elm/compiler/releases/download/#{version}/#{name}"
    bin_path = bin_path()
    archive = fetch_body!(url)
    binary = :zlib.gunzip(archive)

    File.mkdir_p!(Path.dirname(bin_path))
    File.rm(bin_path)
    File.write!(bin_path, binary, [:binary])
    File.chmod(bin_path, 0o755)

    File.mkdir_p!("assets/elm")

    File.write!(Path.expand("assets/elm/elm.json"), """
    {
      "type": "application",
      "source-directories": [
          "src"
      ],
      "elm-version": "0.19.1",
      "dependencies": {
          "direct": {
              "elm/browser": "1.0.2",
              "elm/core": "1.0.5",
              "elm/html": "1.0.0"
          },
          "indirect": {
              "elm/json": "1.1.3",
              "elm/time": "1.0.0",
              "elm/url": "1.0.0",
              "elm/virtual-dom": "1.0.2"
          }
      },
      "test-dependencies": {
          "direct": {},
          "indirect": {}
      }
    }
    """)
  end

  # Available targets:
  #  binary-for-linux-64-bit
  #  binary-for-mac-64-bit
  #  binary-for-windows-64-bit
  defp target do
    arch_str = :erlang.system_info(:system_architecture)
    [arch | _] = arch_str |> List.to_string() |> String.split("-")

    case {:os.type(), arch, :erlang.system_info(:wordsize) * 8} do
      {{:win32, _}, _arch, 64} ->
        "windows"

      {{:unix, :darwin}, "x86_64", 64} ->
        "mac"

      {{:unix, _osname}, arch, 64} when arch in ~w(x86_64 amd64) ->
        "linux"

      {{:unix, :darwin}, arch, 64} when arch in ~w(arm aarch64) ->
        raise "elm not available for Apple silicon yet"

      {_os, _arch, _wordsize} ->
        raise "elm is not available for architecture: #{arch_str}"
    end
  end

  defp fetch_body!(url) do
    url = String.to_charlist(url)
    Logger.debug("Downloading elm from #{url}")

    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    if proxy = System.get_env("HTTP_PROXY") || System.get_env("http_proxy") do
      Logger.debug("Using HTTP_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)
      :httpc.set_options([{:proxy, {{String.to_charlist(host), port}, []}}])
    end

    if proxy = System.get_env("HTTPS_PROXY") || System.get_env("https_proxy") do
      Logger.debug("Using HTTPS_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)
      :httpc.set_options([{:https_proxy, {{String.to_charlist(host), port}, []}}])
    end

    # https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/inets
    cacertfile = CAStore.file_path() |> String.to_charlist()

    http_options = [
      ssl: [
        verify: :verify_peer,
        cacertfile: cacertfile,
        depth: 2,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]

    options = [body_format: :binary]

    case :httpc.request(:get, {url, []}, http_options, options) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body

      other ->
        raise "couldn't fetch #{url}: #{inspect(other)}"
    end
  end
end
