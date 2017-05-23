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

  describe "num_cpus" do
    it "returns current CPU count" do
      shell_cpus = `getconf _NPROCESSORS_ONLN || nproc --all || grep -c '^processor' /proc/cpuinfo`.to_i
      num_cpus = System.num_cpus
      num_cpus.should eq(shell_cpus)
    end
  end
end
