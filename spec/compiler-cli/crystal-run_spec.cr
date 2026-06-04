require "./spec_helper"

describe "`crystal run`" do
  it "shows usage with --help" do
    Process.capture_result(crystal, "run", "--help")
      .should(be_success)
      .output.should(contain("Usage: crystal run"))
  end

  it "runs hello world with empty prelude" do
    Process.capture_result(crystal, "run", "--prelude=empty", fixture_path("empty-hello-world.cr"))
      .should(be_success)
      .output.should(eq("hello world\n"))
  end

  it "passes arguments to the target program after --" do
    Process.capture_result(crystal, "run", fixture_path("empty-echo.cr"), "--prelude=empty", "--", "foo", "bar", "--help")
      .should(be_success)
      .output.should(eq("foo\nbar\n--help\n"))
  end

  it "exits with process exit status" do
    Process.capture_result(crystal, "run", "--prelude=empty", fixture_path("empty-exit42.cr"))
      .should(be_failure(42))
  end
end
