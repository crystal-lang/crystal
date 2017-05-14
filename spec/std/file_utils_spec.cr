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

  describe "touch" do
    it "creates file if it doesn't exists" do
      filename = File.join(__DIR__, "data/test_touch.txt")
      begin
        File.exists?(filename).should be_false
        FileUtils.touch(filename)
        File.exists?(filename).should be_true
      ensure
        File.delete filename
      end
    end

    it "creates multiple files if they doesn't exists" do
      paths = [
        File.join(__DIR__, "data/test_touch_1.txt"),
        File.join(__DIR__, "data/test_touch_2.txt"),
        File.join(__DIR__, "data/test_touch_3.txt"),
      ]
      begin
        paths.each { |path| File.exists?(path).should be_false }
        FileUtils.touch(paths)
        paths.each { |path| File.exists?(path).should be_true }
      ensure
        FileUtils.rm_rf(paths)
      end
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

  describe "rm_rf" do
    it "delete recursively a directory" do
      path = "/tmp/crystal_rm_rftest_#{Process.pid}/"
      FileUtils.mkdir(path)
      File.write(File.join(path, "a"), "")
      FileUtils.mkdir(File.join(path, "b"))
      FileUtils.rm_rf(path).should be_nil
      Dir.exists?(path).should be_false
    end

    it "delete recursively multiple directory" do
      path1 = "/tmp/crystal_rm_rftest_#{Process.pid}/"
      path2 = "/tmp/crystal_rm_rftest_#{Process.pid + 1}/"
      FileUtils.mkdir(path1)
      FileUtils.mkdir(path2)
      File.write(File.join(path1, "a"), "")
      File.write(File.join(path2, "a"), "")
      FileUtils.mkdir(File.join(path1, "b"))
      FileUtils.mkdir(File.join(path2, "b"))
      FileUtils.rm_rf([path1, path2]).should be_nil
      Dir.exists?(path1).should be_false
      Dir.exists?(path2).should be_false
    end

    it "doesn't return error on non existing file" do
      path1 = "/tmp/crystal_rm_rftest_#{Process.pid}/"
      path2 = File.join(path1, "a")
      FileUtils.mkdir(path1)
      FileUtils.rm_rf([path1, path2]).should be_nil
    end
  end

  describe "mv" do
    it "moves a file from one place to another" do
      begin
        path1 = "/tmp/crystal_rm_rftest_#{Process.pid}/"
        path2 = "/tmp/crystal_rm_rftest_#{Process.pid + 1}/"
        FileUtils.mkdir([path1, path2])
        path1 = File.join(path1, "a")
        path2 = File.join(path2, "b")
        File.write(path1, "")
        FileUtils.mv(path1, path2).should be_nil
        File.exists?(path1).should be_false
        File.exists?(path2).should be_true
      ensure
        path1 = "/tmp/crystal_rm_rftest_#{Process.pid}/"
        path2 = "/tmp/crystal_rm_rftest_#{Process.pid + 1}/"
        FileUtils.rm_rf([path1, path2])
      end
    end

    it "raises an error if non correct arguments" do
      expect_raises Errno do
        FileUtils.mv("/tmp/crystal_mv_test/a", "/tmp/crystal_mv_test/b")
      end
    end

    it "moves multiple files to one place" do
      begin
        path1 = "/tmp/crystal_rm_rftest_#{Process.pid}/"
        path2 = "/tmp/crystal_rm_rftest_#{Process.pid + 1}/"
        path3 = "/tmp/crystal_rm_rftest_#{Process.pid + 2}/"
        FileUtils.mkdir([path1, path2, path3])
        path1 = File.join(path1, "a")
        path2 = File.join(path2, "b")
        File.write(path1, "")
        File.write(path2, "")
        FileUtils.mv([path1, path2], path3).should be_nil
        File.exists?(path1).should be_false
        File.exists?(path2).should be_false
        File.exists?(File.join(path3, "a")).should be_true
        File.exists?(File.join(path3, "b")).should be_true
      ensure
        path1 = "/tmp/crystal_rm_rftest_#{Process.pid}/"
        path2 = "/tmp/crystal_rm_rftest_#{Process.pid + 1}/"
        path3 = "/tmp/crystal_rm_rftest_#{Process.pid + 2}/"
        FileUtils.rm_rf([path1, path2, path3])
      end
    end

    it "raises an error if dest is non correct" do
      expect_raises ArgumentError do
        FileUtils.mv(["/tmp/crystal_mv_test/a", "/tmp/crystal_mv_test/b"], "/tmp/crystal_not_here")
      end
    end

    it "moves all existing files to destination" do
      begin
        path1 = "/tmp/crystal_rm_rftest_#{Process.pid}/"
        path2 = "/tmp/crystal_rm_rftest_#{Process.pid + 1}/"
        path3 = "/tmp/crystal_rm_rftest_#{Process.pid + 2}/"
        path4 = "/tmp/crystal_rm_rftest_#{Process.pid + 3}/a"
        FileUtils.mkdir([path1, path2, path3])
        path1 = File.join(path1, "a")
        path2 = File.join(path2, "b")
        File.write(path1, "")
        File.write(path2, "")
        FileUtils.mv([path1, path2, path4], path3).should be_nil
        File.exists?(path1).should be_false
        File.exists?(path2).should be_false
        File.exists?(File.join(path3, "a")).should be_true
        File.exists?(File.join(path3, "b")).should be_true
      ensure
        path1 = "/tmp/crystal_rm_rftest_#{Process.pid}/"
        path2 = "/tmp/crystal_rm_rftest_#{Process.pid + 1}/"
        path3 = "/tmp/crystal_rm_rftest_#{Process.pid + 2}/"
        FileUtils.rm_rf([path1, path2, path3])
      end
    end
  end

  it "tests mkdir and rmdir with a new path" do
    path = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    FileUtils.mkdir(path, 0o700).should be_nil
    Dir.exists?(path).should be_true
    FileUtils.rmdir(path).should be_nil
    Dir.exists?(path).should be_false
  end

  it "tests mkdir and rmdir with multiple new paths" do
    path1 = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    path2 = "/tmp/crystal_mkdir_test_#{Process.pid + 1}/"
    FileUtils.mkdir([path1, path2], 0o700).should be_nil
    Dir.exists?(path1).should be_true
    Dir.exists?(path2).should be_true
    FileUtils.rmdir([path1, path2]).should be_nil
    Dir.exists?(path1).should be_false
    Dir.exists?(path2).should be_false
  end

  it "tests mkdir with an existing path" do
    expect_raises Errno do
      Dir.mkdir(__DIR__, 0o700)
    end
  end

  it "tests mkdir with multiples existing paths" do
    expect_raises Errno do
      FileUtils.mkdir([__DIR__, __DIR__], 0o700)
    end
    expect_raises Errno do
      FileUtils.mkdir(["/tmp/crystal_mkdir_test_#{Process.pid}/", __DIR__], 0o700)
    end
  end

  it "tests mkdir_p with a new path" do
    path = "/tmp/crystal_mkdir_ptest_#{Process.pid}/"
    FileUtils.mkdir_p(path).should be_nil
    Dir.exists?(path).should be_true
    path = File.join({path, "a", "b", "c"})
    FileUtils.mkdir_p(path).should be_nil
    Dir.exists?(path).should be_true
  end

  it "tests mkdir_p with multiples new path" do
    path1 = "/tmp/crystal_mkdir_ptest_#{Process.pid}/"
    path2 = "/tmp/crystal_mkdir_ptest_#{Process.pid + 1}"
    FileUtils.mkdir_p([path1, path2]).should be_nil
    Dir.exists?(path1).should be_true
    Dir.exists?(path2).should be_true
    path1 = File.join({path1, "a", "b", "c"})
    path2 = File.join({path2, "a", "b", "c"})
    FileUtils.mkdir_p([path1, path2]).should be_nil
    Dir.exists?(path1).should be_true
    Dir.exists?(path2).should be_true
  end

  it "tests mkdir_p with an existing path" do
    FileUtils.mkdir_p(__DIR__).should be_nil
    expect_raises Errno do
      FileUtils.mkdir_p(__FILE__)
    end
  end

  it "tests mkdir_p with multiple existing path" do
    FileUtils.mkdir_p([__DIR__, __DIR__]).should be_nil
    expect_raises Errno do
      FileUtils.mkdir_p([__FILE__, "/tmp/crystal_mkdir_ptest_#{Process.pid}/"])
    end
  end

  it "tests rmdir with an non existing path" do
    expect_raises Errno do
      FileUtils.rmdir("/tmp/crystal_mkdir_test_#{Process.pid}/tmp/")
    end
  end

  it "tests rmdir with multiple non existing path" do
    expect_raises Errno do
      FileUtils.rmdir(["/tmp/crystal_mkdir_test_#{Process.pid}/tmp/", "/tmp/crystal_mkdir_test_#{Process.pid + 1}/tmp/"])
    end
  end

  it "tests rmdir with a path that cannot be removed" do
    expect_raises Errno do
      FileUtils.rmdir(__DIR__)
    end
  end

  it "tests rmdir with multiple path that cannot be removed" do
    expect_raises Errno do
      FileUtils.rmdir([__DIR__, __DIR__])
    end
  end

  it "tests rm with an existing path" do
    path = "/tmp/crystal_rm_test_#{Process.pid}"
    File.write(path, "")
    FileUtils.rm(path).should be_nil
    File.exists?(path).should be_false
  end

  it "tests rm with non existing path" do
    expect_raises Errno do
      FileUtils.rm("/tmp/crystal_rm_test_#{Process.pid}")
    end
  end

  it "tests rm with multiple existing paths" do
    path1 = "/tmp/crystal_rm_test_#{Process.pid}"
    path2 = "/tmp/crystal_rm_test_#{Process.pid + 1}"
    File.write(path1, "")
    File.write(path2, "")
    FileUtils.rm([path1, path2]).should be_nil
    File.exists?(path1).should be_false
    File.exists?(path2).should be_false
  end

  it "tests rm with some non existing paths" do
    expect_raises Errno do
      path1 = "/tmp/crystal_rm_test_#{Process.pid}"
      path2 = "/tmp/crystal_rm_test_#{Process.pid + 1}"
      File.write(path1, "")
      File.write(path2, "")
      FileUtils.rm([path1, path2, path2])
    end
  end
end
