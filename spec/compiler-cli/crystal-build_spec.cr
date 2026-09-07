require "./spec_helper"

describe "`crystal build`" do
  it "builds hello world with empty prelude" do
    with_temp_executable "hello-world" do |output_path|
      fixture = fixture_path("empty-hello-world.cr")

      # Build the program
      Process.capture_result(crystal, "build", "--prelude=empty", "-o", output_path, fixture)
        .should(be_success)

      File::Info.executable?(output_path).should be_true

      # Run the built program
      Process.capture_result(output_path)
        .should(be_success)
        .output.should(eq("hello world\n"))
    end
  end

  it "builds hello world in release mode" do
    with_temp_executable "hello-world-release" do |output_path|
      fixture = fixture_path("hello-world.cr")

      Process.capture_result(crystal, "build", "--release", "-o", output_path, fixture)
        .should(be_success)

      File::Info.executable?(output_path).should be_true

      Process.capture_result(output_path)
        .should(be_success)
        .output.should(eq("hello world\n"))
    end
  end

  it "syntax error" do
    Process.capture_result(crystal, "build", fixture_path("syntax-error.cr.txt"))
      .should(be_failure(1))
      .error.should(contain("Error: Unterminated string literal"))
  end

  it "semantic error" do
    Process.capture_result(crystal, "build", fixture_path("semantic-error.cr"))
      .should(be_failure(1))
      .error.should(contain("Error: undefined method 'frobulate' for Int32"))
  end
end
