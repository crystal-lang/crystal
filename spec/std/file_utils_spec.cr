require "spec"
require "file_utils"

describe "FileUtils" do
  describe "cmp" do
    it "compares two equal files" do
      expect(FileUtils.cmp("#{__DIR__}/data/test_file.txt", "#{__DIR__}/data/test_file.txt")).to be_true
    end

    it "compares two different files" do
      expect(FileUtils.cmp("#{__DIR__}/data/test_file.txt", "#{__DIR__}/data/test_file.ini")).to be_false
    end
  end
end
