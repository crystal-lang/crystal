require "./spec_helper"
require "json"

private def capture_with_redirected_stdout_and_tty_stderr(args : Array(String), stdout_path = "/dev/null")
  pending! "requires Linux util-linux script" unless {{ flag?(:linux) }}

  script = Process.find_executable("script") || pending! "requires util-linux script"
  version = Process.capture_result(script, "--version")
  pending! "requires util-linux script" unless version.status.success? && version.output.includes?("util-linux")

  command = "#{Process.quote_posix(args)} > #{Process.quote_posix(stdout_path)}"
  Process.capture_result(
    script,
    "-q",
    "-e",
    "-c",
    command,
    "/dev/null",
    env: {"TERM" => "xterm", "NO_COLOR" => nil}
  )
end

describe "compiler diagnostic colors" do
  it "keeps diagnostics captured over a non-TTY ANSI-free" do
    result = Process.capture_result(
      crystal,
      "build",
      "--no-codegen",
      "--error-trace",
      fixture_path("overload-error.cr")
    )

    result.should be_failure(1)
    result.error.should contain("Overloads are:")
    result.error.should_not contain("\e[")
  end

  it "propagates disabled color to semantic diagnostics" do
    result = Process.capture_result(
      crystal,
      "build",
      "--no-codegen",
      fixture_path("semantic-color-hint-error.cr")
    )

    result.should be_failure(1)
    result.error.should contain("modules cannot be instantiated")
    result.error.should_not contain("\e[")
  end

  it "keeps stderr diagnostics colored when only stdout is redirected" do
    result = capture_with_redirected_stdout_and_tty_stderr([
      crystal,
      "build",
      "--no-codegen",
      fixture_path("semantic-color-hint-error.cr"),
    ])

    result.should be_failure(1)
    result.output.should contain("\e[36mWidget\e[39m")
    result.output.should contain("\e[33;1m (modules cannot be instantiated)\e[39;22m")
  end

  it "forces --no-color when stderr is a TTY" do
    result = capture_with_redirected_stdout_and_tty_stderr([
      crystal,
      "build",
      "--no-codegen",
      "--no-color",
      fixture_path("semantic-color-hint-error.cr"),
    ])

    result.should be_failure(1)
    result.output.should contain("modules cannot be instantiated")
    result.output.should_not contain("\e[")
  end

  it "keeps redirected hierarchy output ANSI-free while stderr is a TTY" do
    with_tempfile("hierarchy-output.txt") do |output_path|
      result = capture_with_redirected_stdout_and_tty_stderr([
        crystal,
        "tool",
        "hierarchy",
        "-e",
        "Widget",
        fixture_path("hierarchy-color.cr"),
      ], output_path)

      result.should be_success
      output = File.read(output_path)
      output.should contain("Widget")
      output.should_not contain("\e[")
    end
  end

  it "propagates disabled color to macro_run diagnostics" do
    result = Process.capture_result(
      crystal,
      "build",
      "--no-codegen",
      fixture_path("macro-run-semantic-color-hint-error.cr")
    )

    result.should be_failure(1)
    result.error.should contain("modules cannot be instantiated")
    result.error.should_not contain("\e[")
  end

  it "keeps JSON diagnostics ANSI-free and valid" do
    result = Process.capture_result(
      crystal,
      "build",
      "--no-codegen",
      "--format",
      "json",
      fixture_path("overload-error.cr")
    )

    result.should be_failure(1)
    parsed = JSON.parse(result.error).as_a
    parsed.should_not be_empty
    parsed.any? { |frame| frame["message"].as_s.includes?("Overloads are:") }.should be_true
    parsed.each do |frame|
      frame["message"].as_s.should_not contain("\e[")
    end
  end

  it "forces JSON diagnostics ANSI-free when stderr is a TTY" do
    result = capture_with_redirected_stdout_and_tty_stderr([
      crystal,
      "build",
      "--no-codegen",
      "--format",
      "json",
      fixture_path("semantic-color-hint-error.cr"),
    ])

    result.should be_failure(1)
    parsed = JSON.parse(result.output).as_a
    parsed.any? { |frame| frame["message"].as_s.includes?("modules cannot be instantiated") }.should be_true
    parsed.each do |frame|
      frame["message"].as_s.should_not contain("\e[")
    end
  end
end
