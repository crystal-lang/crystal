require "spec"
require "file_utils"

describe "FileUtils" do
  describe "cmp" do
    it "compares two equal files" do
      FileUtils.cmp(
        File.join(__DIR__, "data/test_file.txt"),
        File.join(__DIR__, "data/test_file.txt")
      ).should be_true
    end

    it "compares two different files" do
      FileUtils.cmp(
        File.join(__DIR__, "data/test_file.txt"),
        File.join(__DIR__, "data/test_file.ini")
      ).should be_false
    end
  end

  describe "cp" do
    it "copies a file" do
      src_path = File.join(__DIR__, "data/test_file.txt")
      out_path = File.join(__DIR__, "data/test_file_cp.txt")
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
        FileUtils.cp({File.join(__DIR__, "data/test_file.text")}, "not_existing_dir")
      end
    end

    it "copies multiple files" do
      src_name1 = "test_file.txt"
      src_name2 = "test_file.ini"
      src_path = File.join(__DIR__, "data")
      out_path = File.join(__DIR__, "data/cps_path")

      begin
        Dir.mkdir(out_path) rescue nil
        FileUtils.cp({File.join(src_path, src_name1), File.join(src_path, src_name2)}, out_path)
        File.exists?(File.join(out_path, src_name1)).should be_true
        File.exists?(File.join(out_path, src_name2)).should be_true
        FileUtils.cmp(File.join(src_path, src_name1), File.join(out_path, src_name1)).should be_true
        FileUtils.cmp(File.join(src_path, src_name2), File.join(out_path, src_name2)).should be_true
      ensure
        FileUtils.rm_r(out_path) if File.exists?(out_path)
      end
    end
  end

  describe "cp_r" do
    it "copies a directory recursively" do
      path = File.join(__DIR__, "data")
      src_path = File.join(path, "cp_r_test")
      dest_path = File.join(path, "cp_r_test_copied")

      begin
        Dir.mkdir(src_path)
        File.write(File.join(src_path, "a"), "")
        Dir.mkdir(File.join(src_path, "b"))
        File.write(File.join(src_path, "b/c"), "")

        FileUtils.cp_r(src_path, dest_path)
        File.exists?(File.join(dest_path, "a")).should be_true
        File.exists?(File.join(dest_path, "b/c")).should be_true
      ensure
        FileUtils.rm_r(src_path) if File.exists?(src_path)
        FileUtils.rm_r(dest_path) if File.exists?(dest_path)
      end
    end
  end

  describe "rm_r" do
    it "deletes a directory recursively" do
      data_path = File.join(__DIR__, "data")
      path = File.join(data_path, "rm_r_test")

      begin
        Dir.mkdir(path)
        File.write(File.join(path, "a"), "")
        Dir.mkdir(File.join(path, "b"))
        File.write(File.join(path, "b/c"), "")

        FileUtils.rm_r(path)
        Dir.exists?(path).should be_false
      ensure
        File.delete(File.join(path, "b/c")) if File.exists?(File.join(path, "b/c"))
        File.delete(File.join(path, "a")) if File.exists?(File.join(path, "a"))
        Dir.rmdir(File.join(path, "b")) if Dir.exists?(File.join(path, "b"))
        Dir.rmdir(path) if Dir.exists?(path)
      end
    end

    it "doesn't follow symlinks" do
      data_path = File.join(__DIR__, "data")
      removed_path = File.join(data_path, "rm_r_test_removed")
      linked_path = File.join(data_path, "rm_r_test_linked")
      link_path = File.join(removed_path, "link")
      file_path = File.join(linked_path, "file")

      begin
        Dir.mkdir(removed_path)
        Dir.mkdir(linked_path)
        File.symlink(linked_path, link_path)
        File.write(file_path, "")

        FileUtils.rm_r(removed_path)
        Dir.exists?(removed_path).should be_false
        Dir.exists?(linked_path).should be_true
        File.exists?(file_path).should be_true
      ensure
        File.delete(file_path) if File.exists?(file_path)
        File.delete(link_path) if File.exists?(link_path)
        Dir.rmdir(linked_path) if Dir.exists?(linked_path)
        Dir.rmdir(removed_path) if Dir.exists?(removed_path)
      end
    end
  end
end
