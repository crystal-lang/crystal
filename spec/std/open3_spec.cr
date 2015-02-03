require "spec"
require "open3"

def nullify_io(std)
  original = std
  File.open("/dev/null") do |null|
    null.reopen(std)
    yield
  end
ensure
  original.reopen(std) if original
end

describe "Open3" do
  describe "capture2" do
    it "captures STDOUT only" do
      nullify_io(STDERR) do
        output, status = Open3.capture2({"ls", ".", "*"}, env: { LANG: "C" })
        output.should match(/src/)
        output.should_not match(/No such file or directory/)
        status.should eq(2)
      end
    end

    it "collects child process status" do
      output, status = Open3.capture2("ls")
      output.should match(/spec/)
      status.should eq(0)
    end
  end

  describe("capture2e") do
    it "merges and captures STDOUT and STDERR" do
      output, status = Open3.capture2e({"ls", ".", "*"}, env: { LANG: "C" })
      output.should match(/src/)
      output.should match(/No such file or directory/)
      status.should_not eq(0)
    end

    it "collects child process status" do
      output, status = Open3.capture2e("ls")
      output.should match(/spec/)
      status.should eq(0)
    end
  end

  describe "capture3" do
    it "capture3 captures STDOUT and STDERR" do
      output, error, status = Open3.capture3({"ls", ".", "*"}, env: { LANG: "C" })
      output.should match(/spec/)
      error.should match(/No such file or directory/)
      status.should_not eq(0)
    end

    it "collects child process status" do
      output, error, status = Open3.capture3("ls")
      output.should match(/spec/)
      error.should eq("")
      status.should eq(0)
    end
  end
end
