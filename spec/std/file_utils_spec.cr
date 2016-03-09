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

  describe "cp" do
    it "copies a file" do
      src_path = "#{__DIR__}/data/test_file.txt"
      out_path = "#{__DIR__}/data/test_file_cp.txt"
      begin
        FileUtils.cp(src_path, out_path)
        File.exists?(out_path).should be_true
        FileUtils.cmp(src_path, out_path).should be_true
      ensure
        File.delete(out_path) if File.exists?(out_path)
      end
    end

    it "raises an error if the directory doesn't exists" do
      expect_raises(ArgumentError, "no such directory : not_existing_dir") do
        FileUtils.cp({"#{__DIR__}/data/test_file.text"}, "not_existing_dir")
      end
    end

    it "copies multiple files" do
      src_name1 = "test_file.txt"
      src_name2 = "test_file.ini"
      src_path = "#{__DIR__}/data/"
      out_path = "#{__DIR__}/data/cps_path/"

      begin
        Dir.mkdir(out_path) rescue nil
        FileUtils.cp({src_path + src_name1, src_path + src_name2}, out_path)
        File.exists?(out_path + src_name1).should be_true
        File.exists?(out_path + src_name2).should be_true
        FileUtils.cmp(src_path + src_name1, out_path + src_name1).should be_true
        FileUtils.cmp(src_path + src_name2, out_path + src_name2).should be_true
      ensure
        File.delete(out_path + src_name1) if File.exists?(out_path + src_name1)
        File.delete(out_path + src_name2) if File.exists?(out_path + src_name2)
        Dir.rmdir(out_path) if Dir.exists?(out_path)
      end
    end
  end
end
