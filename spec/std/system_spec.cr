require "./spec_helper"
require "system"

describe System do
  describe "hostname" do
    it "returns current hostname" do
      shell_hostname = `hostname`.strip
      pending! "`hostname` command was unsuccessful" unless $?.success?

      hostname = System.hostname
      hostname.should eq(shell_hostname)
    end
  end

  describe "cpu_count" do
    it "returns current CPU count" do
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
end
