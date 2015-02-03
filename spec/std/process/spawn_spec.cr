require "spec"

describe "Process" do
  describe "spawn" do
    it "executes a shell command and nullifies STDOUT" do
      pid = Process.spawn("ls *", output: "/dev/null")
      Process.waitpid(pid).should eq(0)
    end

    it "executes a command and nullifies STDERR" do
      pid = Process.spawn({"ls", "*"}, error: "/dev/null")
      Process.waitpid(pid).should_not eq(0)
    end

    it "exports environment variables and redirects STDOUT" do
      IO.pipe do |r, w|
        pid = Process.spawn("echo $MY_ENV_VAR", env: { MY_ENV_VAR: "MY_ENV_VALUE" }, output: w)
        w.close
        r.gets_to_end.should eq("MY_ENV_VALUE\n")
        Process.waitpid(pid).should eq(0)
      end
    end

    it "writes to STDIN" do
      IO.pipe do |r, w|
        pid = Process.spawn("cat -", input: "my input\nmessage\n", output: w)
        w.close
        r.gets_to_end.should eq("my input\nmessage\n")
        Process.waitpid(pid).should eq(0)
      end
    end

    it "pipes to STDIN" do
      IO.pipe do |in_r, in_w|
        IO.pipe do |out_r, out_w|
          in_w.print("my input message\n")
          in_w.close

          pid = Process.spawn({"cat"}, input: in_r, output: out_w)
          in_r.close
          out_w.close

          out_r.gets_to_end.should eq("my input message\n")
          Process.waitpid(pid).should eq(0)
        end
      end
    end

    # FIXME: subject to raise conditions (fork may run setsid later)
    it "changes sid of child process" do
      pid = Process.spawn("sleep 0.02", pgroup: true)
      sleep(0.01)
      Process.getsid(pid).should_not eq(Process.getsid)
      Process.waitpid(pid).should eq(0)
    end
  end
end
