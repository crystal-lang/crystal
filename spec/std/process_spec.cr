require "spec"

describe "Process" do
  describe "kill" do
    it "terminates a child process" do
      pid = Process.spawn("sleep 2")
      Process.kill(pid).should eq(true)
      Process.waitpid(pid).should eq(0)
    end

    it "kills a child process" do
      pid = Process.spawn("sleep 2")
      Process.kill(pid, Signal::KILL).should eq(true)
      Process.waitpid(pid).should eq(0)
    end

    it "raises exception when process can't be killed" do
      pid = Process.spawn({"/bin/ls"}, output: false)
      Process.waitpid(pid)
      expect_raises(Errno) { Process.kill(pid).should eq(false) }
    end
  end
end
