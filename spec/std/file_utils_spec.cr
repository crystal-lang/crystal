require "spec"
require "file_utils"

private class OneByOneIO
  include IO

  @bytes : Bytes

  def initialize(string)
    @bytes = string.to_slice
    @pos = 0
  end

  def read(slice : Bytes)
    return 0 if slice.empty?
    return 0 if @pos >= @bytes.size

    slice[0] = @bytes[@pos]
    @pos += 1
    1
  end

  def write(slice : Bytes) : Nil
  end
end

describe "FileUtils" do
  describe "cd" do
    it "should work" do
      cwd = Dir.current
      FileUtils.cd("..")
      Dir.current.should_not eq(cwd)
      FileUtils.cd(cwd)
      Dir.current.should eq(cwd)
    end

    it "raises" do
      expect_raises do
        FileUtils.cd("/nope")
      end
    end

    it "accepts a block" do
      cwd = Dir.current

      FileUtils.cd("..") do
        Dir.current.should_not eq(cwd)
      end

      Dir.current.should eq(cwd)
    end
  end

  describe "pwd" do
    it "returns the current working directory" do
      FileUtils.pwd.should eq(Dir.current)
    end
  end

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

    it "compares two ios, one way (true)" do
      io1 = OneByOneIO.new("hello")
      io2 = IO::Memory.new("hello")
      FileUtils.cmp(io1, io2).should be_true
    end

    it "compares two ios, second way (true)" do
      io1 = OneByOneIO.new("hello")
      io2 = IO::Memory.new("hello")
      FileUtils.cmp(io2, io1).should be_true
    end

    it "compares two ios, one way (false)" do
      io1 = OneByOneIO.new("hello")
      io2 = IO::Memory.new("hella")
      FileUtils.cmp(io1, io2).should be_false
    end

    it "compares two ios, second way (false)" do
      io1 = OneByOneIO.new("hello")
      io2 = IO::Memory.new("hella")
      FileUtils.cmp(io2, io1).should be_false
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
      expect_raises(ArgumentError, "No such directory : not_existing_dir") do
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
end
