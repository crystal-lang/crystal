require "spec"
require "process"

describe Process do
  it "runs true" do
    process = Process.new("true")
    process.wait.exit_code.should eq(0)
  end

  it "runs false" do
    process = Process.new("false")
    process.wait.exit_code.should eq(1)
  end

  it "returns status 127 if command could not be executed" do
    process = Process.new("foobarbaz")
    process.wait.exit_code.should eq(127)
  end

  it "run waits for the process" do
    Process.run("true").exit_code.should eq(0)
  end

  it "runs true in block" do
    Process.run("true") { }
    $?.exit_code.should eq(0)
  end

  it "receives arguments in array" do
    Process.run("/bin/sh", ["-c", "exit 123"]).exit_code.should eq(123)
  end

  it "receives arguments in tuple" do
    Process.run("/bin/sh", {"-c", "exit 123"}).exit_code.should eq(123)
  end

  it "redirects output to /dev/null" do
    # This doesn't test anything but no output should be seen while running tests
    Process.run("/bin/ls", output: false).exit_code.should eq(0)
  end

  it "gets output" do
    value = Process.run("/bin/sh", {"-c", "echo hello"}) do |proc|
      proc.output.gets_to_end
    end
    value.should eq("hello\n")
  end

  it "sends input in IO" do
    value = Process.run("/bin/cat", input: MemoryIO.new("hello")) do |proc|
      proc.input?.should be_nil
      proc.output.gets_to_end
    end
    value.should eq("hello")
  end

  it "sends output to IO" do
    output = MemoryIO.new
    Process.run("/bin/sh", {"-c", "echo hello"}, output: output)
    output.to_s.should eq("hello\n")
  end

  it "sends error to IO" do
    error = MemoryIO.new
    Process.run("/bin/sh", {"-c", "echo hello 1>&2"}, error: error)
    error.to_s.should eq("hello\n")
  end

  it "controls process in block" do
    value = Process.run("/bin/cat") do |proc|
      proc.input.print "hello"
      proc.input.close
      proc.output.gets_to_end
    end
    value.should eq("hello")
  end

  it "closes ios after block" do
    Process.run("/bin/cat") { }
    $?.exit_code.should eq(0)
  end

  it "sets working directory" do
    parent = File.dirname(Dir.working_directory)
    value = Process.run("pwd", shell: true, chdir: parent, output: nil) do |proc|
      proc.output.gets_to_end
    end
    value.should eq "#{parent}\n"
  end

  it "disallows passing arguments to nowhere" do
    expect_raises ArgumentError, /args.+@/ do
      Process.run("foo bar", {"baz"}, shell: true)
    end
  end

  it "looks up programs in the $PATH with a shell" do
    proc = Process.run("uname", {"-a"}, shell: true, output: false)
    proc.exit_code.should eq(0)
  end

  it "allows passing huge argument lists to a shell" do
    proc = Process.new(%(echo "${@}"), {"a", "b"}, shell: true, output: nil)
    output = proc.output.gets_to_end
    proc.wait
    output.should eq "a b\n"
  end

  it "does not run shell code in the argument list" do
    proc = Process.new("echo", {"`echo hi`"}, shell: true, output: nil)
    output = proc.output.gets_to_end
    proc.wait
    output.should eq "`echo hi`\n"
  end

  describe "environ" do
    it "clears the environment" do
      value = Process.run("env", clear_env: true) do |proc|
        proc.output.gets_to_end
      end
      value.should eq("")
    end

    it "sets an environment variable" do
      env = {"FOO" => "bar"}
      value = Process.run("env", clear_env: true, env: env) do |proc|
        proc.output.gets_to_end
      end
      value.should eq("FOO=bar\n")
    end

    it "deletes an environment variable" do
      env = {"HOME" => nil}
      value = Process.run("env | egrep '^HOME='", env: env, shell: true) do |proc|
        proc.output.gets_to_end
      end
      value.should eq("")
    end
  end

  describe "kill" do
    it "kills a process" do
      process = fork { loop { } }
      process.kill(Signal::KILL).should be_nil
    end

    it "kills many process" do
      process1 = fork { loop { } }
      process2 = fork { loop { } }
      process1.kill(Signal::KILL).should be_nil
      process2.kill(Signal::KILL).should be_nil
    end
  end

  it "gets the pgid of a process id" do
    process = fork { loop { } }
    Process.getpgid(process.pid).should be_a(Int32)
    process.kill(Signal::KILL)
  end

  it "can link processes together" do
    buffer = MemoryIO.new
    Process.run("/bin/cat") do |cat|
      Process.run("/bin/cat", input: cat.output, output: buffer) do
        1000.times { cat.input.puts "line" }
        cat.close
      end
    end
    buffer.to_s.lines.size.should eq(1000)
  end
end
