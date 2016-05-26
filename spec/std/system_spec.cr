require "spec"
require "system"

describe System do
  describe "hostname" do
    it "returns current hostname" do
      shell_hostname = `hostname`.strip
      hostname = System.hostname
      hostname.should eq(shell_hostname)
    end
  end
end
