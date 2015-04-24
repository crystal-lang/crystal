require "spec"

describe "Process.run" do
  it "gets status code from successful process" do
    expect(Process.run("true").exit).to eq(0)
  end

  it "gets status code from failed process" do
    expect(Process.run("false").exit).to eq(1)
  end

  it "returns status 127 if command could not be executed" do
    expect(Process.run("foobarbaz", output: true).exit).to eq(127)
  end

  it "includes PID in process status " do
    expect(Process.run("true").pid).to be > 0
  end

  it "receives arguments in array" do
    expect(Process.run("/bin/sh", ["-c", "exit 123"]).exit).to eq(123)
  end

  it "receives arguments in tuple" do
    expect(Process.run("/bin/sh", {"-c", "exit 123"}).exit).to eq(123)
  end

  it "redirects output to /dev/null" do
    # This doesn't test anything but no output should be seen while running tests
    expect(Process.run("/bin/ls", output: false).exit).to eq(0)
  end

  it "gets output as string" do
    expect(Process.run("/bin/sh", {"-c", "echo hello"}, output: true).output).to eq("hello\n")
  end

  it "send input from string" do
    expect(Process.run("/bin/cat", input: "hello", output: true).output).to eq("hello")
  end

  it "send input from IO" do
    File.open(__FILE__, "r") do |file|
      expect(Process.run("/bin/cat", input: file, output: true).output).to eq(File.read(__FILE__))
    end
  end

  it "send output to IO" do
    io = StringIO.new
    expect(Process.run("/bin/cat", input: "hello", output: io).output).to be_nil
    expect(io.to_s).to eq("hello")
  end
end
