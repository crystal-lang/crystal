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

  describe "cp_r" do
    it "copies a directory recursively" do
      path = "#{__DIR__}/data/"
      src_path = path + "cp_r_test/"
      dest_path = path + "cp_r_test_copied/"

      begin
        Dir.mkdir(src_path)
        File.new(src_path + "a", "w").close
        Dir.mkdir(src_path + "b")
        File.new(src_path + "b/c", "w").close

        FileUtils.cp_r(src_path, dest_path)
        File.exists?(dest_path + "a").should be_true
        File.exists?(dest_path + "b/c").should be_true
      ensure
        File.delete(dest_path + "b/c") if File.exists?(dest_path + "b/c")
        File.delete(dest_path + "a") if File.exists?(dest_path + "a")
        Dir.rmdir(dest_path + "b") if Dir.exists?(dest_path)
        Dir.rmdir(dest_path) if Dir.exists?(dest_path)
        File.delete(src_path + "b/c") if File.exists?(src_path + "b/c")
        File.delete(src_path + "a") if File.exists?(src_path + "a")
        Dir.rmdir(src_path + "b") if Dir.exists?(src_path)
        Dir.rmdir(src_path) if Dir.exists?(src_path)
      end
    end
  end

  describe "rm_r" do
    it "deletes a directory recursively" do
      data_path = "#{__DIR__}/data/"
      path = data_path + "rm_r_test/"

      begin
        Dir.mkdir(path)
        File.new(path + "a", "w").close
        Dir.mkdir(path + "b")
        File.new(path + "b/c", "w").close

        FileUtils.rm_r(path)
        Dir.exists?(path).should be_false
      ensure
        File.delete(path + "b/c") if File.exists?(path + "b/c")
        File.delete(path + "a") if File.exists?(path + "a")
        Dir.rmdir(path + "b") if Dir.exists?(path)
        Dir.rmdir(path) if Dir.exists?(path)
      end
    end
  end
end
