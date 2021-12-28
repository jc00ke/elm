defmodule ElmTest do
  use ExUnit.Case, async: true

  @version Elm.latest_version()

  test "run on default" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Elm.run(:default, ["--version"]) == 0
           end) =~ @version

    assert File.exists?("assets/elm/elm.json")
  end

  test "run on profile" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Elm.run(:another, []) == 0
           end) =~ @version
  end

  test "installs" do
    Application.delete_env(:elm, :version)

    Mix.Task.rerun("elm.install", ["--if-missing"])

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Elm.run(:default, ["--version"]) == 0
           end) =~ @version
  end
end
