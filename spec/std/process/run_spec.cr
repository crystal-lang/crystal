require "spec"

describe "Process.run" do
  it "gets status code from successful process" do
    Process.run("true").exit.should eq(0)
  end

  it "gets status code from failed process" do
    Process.run("false").exit.should eq(1)
  end

  it "returns status 127 if command could not be executed" do
    Process.run("foobarbaz", output: true).exit.should eq(127)
  end

  it "includes PID in process status " do
    Process.run("true").pid.should be > 0
  end

  it "receives arguments in array" do
    Process.run("/bin/sh", ["-c", "exit 123"]).exit.should eq(123)
  end

  it "receives arguments in tuple" do
    Process.run("/bin/sh", {"-c", "exit 123"}).exit.should eq(123)
  end

  it "redirects output to /dev/null" do
    # This doesn't test anything but no output should be seen while running tests
    Process.run("/bin/ls", output: false).exit.should eq(0)
  end

  it "gets output as string" do
    Process.run("/bin/sh", {"-c", "echo hello"}, output: true).output.should eq("hello\n")
  end

  it "send input from string" do
    Process.run("/bin/cat", input: "hello", output: true).output.should eq("hello")
  end

  it "send input from IO" do
    File.open(__FILE__, "r") do |file|
      Process.run("/bin/cat", input: file, output: true).output.should eq(File.read(__FILE__))
    end
  end

  it "send output to IO" do
    io = StringIO.new
    Process.run("/bin/cat", input: "hello", output: io).output.should be_nil
    io.to_s.should eq("hello")
  end

  it "redirects error to /dev/null" do
    # This doesn't test anything but no output should be seen while running tests
    Process.run("/bin/sh", {"-c",  "ls 1>&2"}, error: false).exit.should eq(0)
  end

  it "gets error as string" do
    Process.run("/bin/sh", {"-c",  "cat 1>&2"}, input: "hello", error: true).error.should eq("hello")
  end

  it "sends error to IO" do
    io = StringIO.new
    Process.run("/bin/sh", {"-c",  "cat 1>&2"}, input: "hello", error: io).error.should be_nil
    io.to_s.should eq("hello")
  end

  it "sends output to error" do
    status = Process.run("/bin/sh", {"-c",  "cat 1>&2"}, input: "hello", output: :error, error: true)
    status.output.should be_nil
    status.error.should eq("hello")
  end

  it "sends output to error with IO" do
    io = StringIO.new
    status = Process.run("/bin/sh", {"-c",  "cat 1>&2"}, input: "hello", output: :error, error: io)
    status.output.should be_nil
    status.error.should be_nil
    io.to_s.should eq("hello")
  end

  it "sends output to error to /dev/null" do
    # This doesn't test anything but no output should be seen while running tests
    status = Process.run("/bin/sh", {"-c",  "cat 1>&2"}, input: "hello", output: :error, error: false)
  end

  it "sends error to output" do
    status = Process.run("/bin/sh", {"-c",  "cat 1>&2"}, input: "hello", output: true, error: :output)
    status.output.should eq("hello")
    status.error.should be_nil
  end

  it "sends error to output with IO" do
    io = StringIO.new
    status = Process.run("/bin/sh", {"-c",  "cat 1>&2"}, input: "hello", output: io, error: :output)
    status.output.should be_nil
    status.error.should be_nil
    io.to_s.should eq("hello")
  end

  it "sends error to output to /dev/null" do
    # This doesn't test anything but no output should be seen while running tests
    status = Process.run("/bin/sh", {"-c",  "cat 1>&2"}, input: "hello", output: false, error: :output)
  end

  it "raises if another symbol is passed to output" do
    expect_raises do
      Process.run("/bin/ls", output: :foo)
    end
  end

  it "raises if another symbol is passed to error" do
    expect_raises do
      Process.run("/bin/ls", error: :foo)
    end
  end

  it "raises on circular redirection" do
    expect_raises do
      Process.run("/bin/ls", output: :errror, error: :output)
    end
  end
end
