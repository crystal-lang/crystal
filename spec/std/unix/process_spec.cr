{% skip_file unless flag?(:unix) %}

require "spec"
require "unix/process"
require "../spec_helper"
require "../../support/env"

private def exit_code_command(code)
  {"/bin/sh", {"-c", "exit #{code}"}}
end

describe UNIX::Process do
  describe ".fork (no block)" do
    it "returns UNIX::Process in parent and nil in child" do
      if child = UNIX::Process.fork
        child.should be_a(UNIX::Process)
        child.wait
      else
        LibC._exit 0
      end
    end

    it "typeof returns UNIX::Process?" do
      typeof(UNIX::Process.fork).should eq(UNIX::Process?)
    end
  end

  describe ".fork (with block)" do
    it "returns UNIX::Process from parent side" do
      child = UNIX::Process.fork { LibC._exit 0 }
      child.should be_a(UNIX::Process)
      child.wait
    end

    it "executes a command in the child via exec" do
      with_tempfile("unix-process-fork-exec") do |path|
        File.exists?(path).should be_false
        child = UNIX::Process.fork do
          UNIX::Process.exec("/usr/bin/env", {"touch", path})
        end
        child.wait
        File.exists?(path).should be_true
      end
    end
  end

  describe ".exec" do
    it "replaces the process" do
      with_tempfile("unix-exec-stdout") do |stdout_path|
        status, _, _ = compile_and_run_source <<-CRYSTAL
          require "unix/process"
          File.open(#{stdout_path.inspect}, "w") do |fd|
            UNIX::Process.exec(#{exit_code_command(0)[0].inspect},
              #{exit_code_command(0)[1].to_a.inspect} of String,
              output: fd)
          end
          CRYSTAL
        status.success?.should be_true
      end
    end

    it "raises on missing executable" do
      expect_raises(File::NotFoundError) do
        UNIX::Process.exec("__no_such_binary__")
      end
    end
  end

  describe ".pgid" do
    it "returns an integer for the current process" do
      UNIX::Process.pgid.should be_a(Int64)
    end

    it "returns an integer for a known pid" do
      UNIX::Process.pgid(Process.pid).should be_a(Int64)
    end
  end

  describe ".signal" do
    it "sends a signal to a child process" do
      child = UNIX::Process.fork
      if child
        UNIX::Process.signal(Signal::TERM, child.pid)
        child.wait
      else
        sleep
      end
    end
  end

  describe "#signal" do
    it "sends a signal to a child UNIX::Process" do
      child = UNIX::Process.fork
      if child
        child.signal(Signal::KILL)
        child.wait
      else
        sleep
      end
    end
  end

  {% unless flag?(:android) %}
    describe ".chroot" do
      it "raises when unprivileged" do
        expect_raises(RuntimeError, /EPERM/) do
          UNIX::Process.chroot(".")
        end
      end
    end
  {% end %}
end
