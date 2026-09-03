require "./spec_helper"

describe "`crystal`" do
  describe "general commands" do
    it "shows top-level usage with --help" do
      Process.capture_result(crystal, "--help")
        .should(be_success)
        .output.should(contain("Usage: crystal [command]"))
        .should(contain("Command:"))
    end

    it "prints version information" do
      Process.capture_result(crystal, "--version")
        .should(be_success)
        .output.should(contain("Crystal"))
        .should(contain("LLVM"))
    end
  end

  describe "filename argument" do
    it "runs a single Crystal file argument" do
      Process.capture_result(crystal, fixture_path("hello-world.cr"))
        .should(be_success)
        .output.should(contain("hello world"))
    end

    it "fails when source file does not exist" do
      Process.capture_result(crystal, "no_such_file.cr")
        .should(be_failure(1))
        .error.should(contain("Error: file 'no_such_file.cr' does not exist"))
    end
  end

  describe "command resolution" do
    it "fails on unknown command" do
      Process.capture_result(crystal, "frobulate")
        .should(be_failure(1))
        .error.should(contain("Error: unknown command: frobulate"))
    end

    it "fails on unknown tool" do
      Process.capture_result(crystal, "tool", "no_such_tool")
        .should(be_failure(1))
        .error.should(contain("Error: unknown tool: no_such_tool"))
    end

    it "accepts command prefix for build" do
      Process.capture_result(crystal, "bu", "--help")
        .should(be_success)
        .output.should(contain("Usage: crystal build"))
    end

    it "accepts command prefix for docs" do
      Process.capture_result(crystal, "do", "--help")
        .should(be_success)
        .output.should(contain("Usage: crystal docs"))
    end

    it "accepts command prefix for spec" do
      Process.capture_result(crystal, "sp", "--help")
        .should(be_success)
        .output.should(contain("Usage: crystal spec"))
    end
  end

  describe "arguments" do
    it "invalid argument value" do
      Process.capture_result(crystal, "--frobulate")
        .should(be_failure(1))
        .error.should(contain("Error: unknown command: --frobulate"))
    end
  end

  it "prints version" do
    version = Process.capture_result(crystal, "env", "CRYSTAL_VERSION")
      .should(be_success).output.strip

    Process.capture_result(crystal, "--version")
      .should(be_success)
      .output.should(contain("Crystal #{version}"))
  end
end
