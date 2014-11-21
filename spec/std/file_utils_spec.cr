require "spec"
require "file_utils"

describe "FileUtils" do
  describe "cmp" do
    it "compares two equal files" do
      FileUtils.cmp("#{__DIR__}/data/test_file.txt", "#{__DIR__}/data/test_file.txt").should be_true
    end

    it "compares two different files" do
      FileUtils.cmp("#{__DIR__}/data/test_file.txt", "#{__DIR__}/data/test_file.ini").should be_false
    end
  end
end
