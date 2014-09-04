#!/usr/bin/env bin/crystal --run
require "spec"

describe "Exec" do
  it "gets status code from successful process" do
    exec("true").exit.should eq(0)
  end

  it "gets status code from failed process" do
    exec("false").exit.should eq(1)
  end

  it "returns status 127 if command could not be executed" do
    exec("foobarbaz", output: true).exit.should eq(127)
  end

  it "includes PID in process status " do
    (exec("true").pid > 0).should be_true
  end

  it "receives arguments in array" do
    exec("/bin/sh", ["-c", "exit 123"]).exit.should eq(123)
  end

  it "receives arguments in tuple" do
    exec("/bin/sh", {"-c", "exit 123"}).exit.should eq(123)
  end

  it "redirects output to /dev/null" do
    # This doesn't test anything but no output should be seen while running tests
    exec("/bin/ls", output: false).exit.should eq(0)
  end

  it "gets output as string" do
    exec("/bin/sh", {"-c", "echo hello"}, output: true).output.should eq("hello\n")
  end

  it "send input from string" do
    exec("/bin/cat", input: "hello", output: true).output.should eq("hello")
  end

  it "send input from IO" do
    File.open(__FILE__, "r") do |file|
      exec("/bin/cat", input: file, output: true).output.should eq(File.read(__FILE__))
    end
  end

  it "send output to IO" do
    io = StringIO.new
    exec("/bin/cat", input: "hello", output: io).output.should be_nil
    io.to_s.should eq("hello")
  end
end
