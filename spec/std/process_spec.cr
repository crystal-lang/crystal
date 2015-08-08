require "spec"

describe Process do
  describe "run" do
    it "gets status code from successful process" do
      Process.run("true").exit.should eq(0)
    end

    it "gets status code from failed process" do
      Process.run("false").exit.should eq(1)
    end

    it "returns status 127 if command could not be executed" do
      Process.run("foobarbaz", output: nil).exit.should eq(127)
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
      Process.run("/bin/sh", {"-c", "echo hello"}, output: nil).output.to_s.should eq("hello\n")
    end

    it "send input from string" do
      Process.run("/bin/cat", input: StringIO.new("hello"), output: nil).output.to_s.should eq("hello")
    end

    it "send input from IO" do
      File.open(__FILE__, "r") do |file|
        Process.run("/bin/cat", input: file, output: nil).output.to_s.should eq(File.read(__FILE__))
      end
    end

    it "send output to IO" do
      io = StringIO.new
      Process.run("/bin/cat", input: StringIO.new("hello"), output: io).output.to_s.should eq("hello")
      io.to_s.should eq("hello")
    end

    it "gets status code from successful process" do
      system("true").should eq(true)
    end

    it "gets status code from failed process" do
      system("false").should eq(false)
    end

    it "gets output as string" do
      `echo hello`.should eq("hello\n")
    end
  end

  describe "popen" do
    it "test alive?" do
      status = Process.popen("sleep", ["60"])
      status.alive?.should be_true
      status.kill
      status.close
      status.alive?.should be_false
    end
  end

  describe "kill" do
    it "kills a process" do
      pid = fork { loop {} }
      Process.kill(Signal::KILL, pid).should eq(0)
    end

    it "kills many process" do
      pid1 = fork { loop { sleep 60 } }
      pid2 = fork { loop { sleep 60 } }
      Process.kill(Signal::KILL, pid1, pid2).should eq(0)
    end
  end

  it "gets the pgid of a process id" do
    pid = fork { loop { sleep 60 } }
    Process.getpgid(pid).should be_a(Int32)
    Process.kill(Signal::KILL, pid)
  end
end
