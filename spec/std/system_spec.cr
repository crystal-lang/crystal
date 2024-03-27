require "./spec_helper"
require "system"

describe System do
  describe "hostname" do
    # can't use backtick in interpreted code (#12241)
    pending_interpreted "returns current hostname" do
      shell_hostname = `hostname`.strip
      pending! "`hostname` command was unsuccessful" unless $?.success?

      hostname = System.hostname
      hostname.should eq(shell_hostname)
    end
  end

  describe "cpu_count" do
    # can't use backtick in interpreted code (#12241)
    pending_interpreted "returns current CPU count" do
      shell_cpus =
        {% if flag?(:win32) %}
          ENV["NUMBER_OF_PROCESSORS"].to_i
        {% elsif flag?(:unix) %}
          `getconf _NPROCESSORS_ONLN 2>/dev/null || nproc --all 2>/dev/null || grep -sc '^processor' /proc/cpuinfo || sysctl -n hw.ncpu 2>/dev/null`.to_i
        {% end %}
      cpu_count = System.cpu_count
      cpu_count.should eq(shell_cpus)
    end
  end

  pending_win32 describe: "file_descriptor_limit" do
    it "returns the current file descriptor limit" do
      hard_fd_limit = `ulimit -Hn`.strip
      $?.success?.should be_true
      soft_fd_limit = `ulimit -Sn`.strip
      $?.success?.should be_true

      soft_limit, hard_limit = System.file_descriptor_limit
      hard_limit.to_s.should eq hard_fd_limit
      soft_limit.to_s.should eq soft_fd_limit
    end

    it "can set the limit" do
      System.file_descriptor_limit = 512

      soft_fd_limit = `ulimit -Sn`.strip
      $?.success?.should be_true
      soft_fd_limit.should eq "512"
    end
  end
end
