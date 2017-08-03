require "spec"
require "system"

describe System do
  describe "hostname" do
    it "returns current hostname" do
      shell_hostname = `hostname`.strip
      $?.success?.should be_true # The hostname command has to be available
      hostname = System.hostname
      hostname.should eq(shell_hostname)
    end
  end

  describe "cpu_count" do
    it "returns current CPU count" do
      shell_cpus = `getconf _NPROCESSORS_ONLN || nproc --all || grep -c '^processor' /proc/cpuinfo || sysctl -n hw.ncpu`.to_i
      cpu_count = System.cpu_count
      cpu_count.should eq(shell_cpus)
    end
  end
end
