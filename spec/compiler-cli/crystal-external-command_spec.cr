require "./spec_helper"

describe "`crystal-*` external commands" do
  exec_path = File.tempname
  echo_env_path = File.join(exec_path, "crystal-echo_env")

  before_all do
    # Build the fixture program that will be invoked as an external command
    Dir.mkdir_p(exec_path)

    Process.capture_result(crystal, "build", "-o", echo_env_path, fixture_path("crystal-echo_env.cr"))
      .should(be_success)
  end

  after_all do
    FileUtils.rm_rf(exec_path)
  end

  it "execs external crystal-* command" do
    # Modify PATH to include the shared directory with our fixture
    Process.capture_result(crystal, "echo_env", "foo", "bar", env: {"PATH" => "#{exec_path}:#{ENV["PATH"]?}"})
      .should(be_success)
      .output.should(contain("crystal="))
      # .should contain("CRYSTAL_EXEC_PATH=#{exec_path}")
      .should(contain("PROGRAM_NAME=#{echo_env_path}"))
      .should(contain(%(ARGV=["foo", "bar"])))
  end

  it "execs external crystal-* command with CRYSTAL_EXEC_PATH" do
    Process.capture_result(crystal, "echo_env", "foo", "bar", env: {"PATH" => "#{exec_path}:#{ENV["PATH"]?}", "CRYSTAL_EXEC_PATH" => exec_path})
      .should(be_success)
      .output.should(contain("crystal="))
      # .should contain("CRYSTAL_EXEC_PATH=#{exec_path}")
      .should(contain("PROGRAM_NAME=#{echo_env_path}"))
      .should(contain(%(ARGV=["foo", "bar"])))
  end
end
