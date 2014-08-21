#!/usr/bin/env bin/crystal --run
require "spec"

describe "Exec" do
  it "gets status code from successful process" do
    exec("true").status.should eq(0)
  end

  it "gets status code from failed process" do
    exec("false").status.should eq(1)
  end

  it "returns status 127 if command could not be executed" do
    exec("foobarbaz", output: true).status.should eq(127)
  end

  it "includes PID in process status " do
    (exec("true").pid > 0).should be_true
  end

  it "receives arguments in array" do
    exec("/bin/sh", ["-c", "exit 123"]).status.should eq(123)
  end

  it "receives arguments in tuple" do
    exec("/bin/sh", {"-c", "exit 123"}).status.should eq(123)
  end

  it "redirects output to /dev/null" do
    # This doesn't test anything but no output should be seen while running tests
    exec("/bin/ls", output: false).status.should eq(0)
  end

  it "gets output as string" do
    exec("/bin/sh", {"-c", "echo hello"}, output: true).output.should eq(["hello"])
  end
end
