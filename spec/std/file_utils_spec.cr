require "./spec_helper"
require "file_utils"
require "../support/errno"

private class OneByOneIO < IO
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
      expect_raises_errno(Errno::ENOENT, "Error while changing directory to '/nope'") do
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
        datapath("test_file.txt"),
        datapath("test_file.txt")
      ).should be_true
    end

    it "compares two different files" do
      FileUtils.cmp(
        datapath("test_file.txt"),
        datapath("test_file.ini")
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
      with_tempfile("touch.txt") do |path|
        File.exists?(path).should be_false
        FileUtils.touch(path)
        File.exists?(path).should be_true
      end
    end

    it "creates multiple files if they don't exists" do
      with_tempfile("touch1", "touch2", "touch3") do |path1, path2, path3|
        paths = [path1, path2, path3]
        paths.each { |path| File.exists?(path).should be_false }
        FileUtils.touch(paths)
        paths.each { |path| File.exists?(path).should be_true }
      end
    end
  end

  describe "cp" do
    it "copies a file" do
      src_path = datapath("test_file.txt")
      with_tempfile("cp.txt") do |out_path|
        FileUtils.cp(src_path, out_path)
        File.exists?(out_path).should be_true
        FileUtils.cmp(src_path, out_path).should be_true
      end
    end

    it "copies permissions" do
      with_tempfile("cp-permissions-src.txt", "cp-permissions-out.txt") do |src_path, out_path|
        File.write(src_path, "foo")
        File.chmod(src_path, 0o700)

        FileUtils.cp(src_path, out_path)

        File.info(out_path).permissions.should eq(File::Permissions.new(0o700))
        FileUtils.cmp(src_path, out_path).should be_true
      end
    end

    it "raises an error if the directory doesn't exists" do
      expect_raises(ArgumentError, "No such directory : not_existing_dir") do
        FileUtils.cp({datapath("test_file.txt")}, "not_existing_dir")
      end
    end

    it "copies multiple files" do
      src_name1 = "test_file.txt"
      src_name2 = "test_file.ini"
      src_path = datapath
      with_tempfile("cp-multiple") do |out_path|
        Dir.mkdir_p(out_path)
        FileUtils.cp({File.join(src_path, src_name1), File.join(src_path, src_name2)}, out_path)
        File.exists?(File.join(out_path, src_name1)).should be_true
        File.exists?(File.join(out_path, src_name2)).should be_true
        FileUtils.cmp(File.join(src_path, src_name1), File.join(out_path, src_name1)).should be_true
        FileUtils.cmp(File.join(src_path, src_name2), File.join(out_path, src_name2)).should be_true
      end
    end
  end

  describe "cp_r" do
    it "copies a directory recursively" do
      with_tempfile("cp_r-test", "cp_r-test-copied") do |src_path, dest_path|
        Dir.mkdir_p(src_path)
        File.write(File.join(src_path, "a"), "")
        Dir.mkdir(File.join(src_path, "b"))
        File.write(File.join(src_path, "b/c"), "")

        FileUtils.cp_r(src_path, dest_path)
        File.exists?(File.join(dest_path, "a")).should be_true
        File.exists?(File.join(dest_path, "b/c")).should be_true
      end
    end
  end

  describe "rm_r" do
    it "deletes a directory recursively" do
      with_tempfile("rm_r") do |path|
        Dir.mkdir(path)
        File.write(File.join(path, "a"), "")
        Dir.mkdir(File.join(path, "b"))
        File.write(File.join(path, "b/c"), "")

        FileUtils.rm_r(path)
        Dir.exists?(path).should be_false
      end
    end

    it "doesn't follow symlinks" do
      with_tempfile("rm_r-removed", "rm_r-linked") do |removed_path, linked_path|
        link_path = File.join(removed_path, "link")
        file_path = File.join(linked_path, "file")

        Dir.mkdir(removed_path)
        Dir.mkdir(linked_path)
        File.symlink(linked_path, link_path)
        File.write(file_path, "")

        FileUtils.rm_r(removed_path)
        Dir.exists?(removed_path).should be_false
        Dir.exists?(linked_path).should be_true
        File.exists?(file_path).should be_true
      end
    end
  end

  describe "rm_rf" do
    it "delete recursively a directory" do
      with_tempfile("rm_rf") do |path|
        FileUtils.mkdir(path)
        File.write(File.join(path, "a"), "")
        FileUtils.mkdir(File.join(path, "b"))
        FileUtils.rm_rf(path).should be_nil
        Dir.exists?(path).should be_false
      end
    end

    it "delete recursively multiple directory" do
      with_tempfile("rm_rf-multi1", "rm_rf-multi2") do |path1, path2|
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
    end

    it "doesn't return error on non existing file" do
      with_tempfile("rm_rf-nonexistent") do |path1|
        path2 = File.join(path1, "a")
        FileUtils.mkdir(path1)
        FileUtils.rm_rf([path1, path2]).should be_nil
      end
    end
  end

  describe "mv" do
    it "moves a file from one place to another" do
      with_tempfile("mv1", "mv2") do |path1, path2|
        FileUtils.mkdir([path1, path2])
        path1 = File.join(path1, "a")
        path2 = File.join(path2, "b")
        File.write(path1, "")
        FileUtils.mv(path1, path2).should be_nil
        File.exists?(path1).should be_false
        File.exists?(path2).should be_true
      end
    end

    it "raises an error if non correct arguments" do
      with_tempfile("mv-nonexitent") do |path|
        expect_raises_errno(Errno::ENOENT, "Error renaming file '#{File.join(path, "a")}' to '#{File.join(path, "b")}'") do
          FileUtils.mv(File.join(path, "a"), File.join(path, "b"))
        end
      end
    end

    it "moves multiple files to one place" do
      with_tempfile("mv-multi1", "mv-multi2", "mv-multi3") do |path1, path2, path3|
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
      end
    end

    it "raises an error if dest is non correct" do
      expect_raises ArgumentError do
        with_tempfile("mv-nonexistent") do |path|
          FileUtils.mv([File.join(path, "a"), File.join(path, "b")], File.join(path, "c"))
        end
      end
    end

    it "moves all existing files to destination" do
      with_tempfile("mv-source", "mv-target") do |source_path, target_path|
        path1 = File.join(source_path, "a")
        path2 = File.join(source_path, "b")
        path3 = File.join(source_path, "c", "sub")

        FileUtils.mkdir_p([path1, path2, target_path])
        path1 = File.join(path1, "a")
        path2 = File.join(path2, "b")
        File.write(path1, "")
        File.write(path2, "")
        FileUtils.mv([path1, path2, path3], target_path).should be_nil
        File.exists?(path1).should be_false
        File.exists?(path2).should be_false
        File.exists?(File.join(target_path, "a")).should be_true
        File.exists?(File.join(target_path, "b")).should be_true
      end
    end
  end

  it "tests mkdir and rmdir with a new path" do
    with_tempfile("mkdir-new") do |path|
      FileUtils.mkdir(path, 0o700).should be_nil
      Dir.exists?(path).should be_true
      FileUtils.rmdir(path).should be_nil
      Dir.exists?(path).should be_false
    end
  end

  it "tests mkdir and rmdir with multiple new paths" do
    with_tempfile("mkdir-new1", "mkdir-new2") do |path1, path2|
      FileUtils.mkdir([path1, path2], 0o700).should be_nil
      Dir.exists?(path1).should be_true
      Dir.exists?(path2).should be_true
      FileUtils.rmdir([path1, path2]).should be_nil
      Dir.exists?(path1).should be_false
      Dir.exists?(path2).should be_false
    end
  end

  it "tests mkdir with an existing path" do
    expect_raises_errno(Errno::EEXIST, "Unable to create directory '#{datapath}'") do
      Dir.mkdir(datapath, 0o700)
    end
  end

  it "tests mkdir with multiples existing paths" do
    expect_raises_errno(Errno::EEXIST, "Unable to create directory '#{datapath}'") do
      FileUtils.mkdir([datapath, datapath], 0o700)
    end

    with_tempfile("mkdir-nonexisting") do |path|
      expect_raises_errno(Errno::EEXIST, "Unable to create directory '#{datapath}'") do
        FileUtils.mkdir([path, datapath], 0o700)
      end
    end
  end

  it "tests mkdir_p with a new path" do
    with_tempfile("mkdir_p-new") do |path1|
      FileUtils.mkdir_p(path1).should be_nil
      Dir.exists?(path1).should be_true
      path2 = File.join({path1, "a", "b", "c"})
      FileUtils.mkdir_p(path2).should be_nil
      Dir.exists?(path2).should be_true
    end
  end

  it "tests mkdir_p with multiples new path" do
    with_tempfile("mkdir_p-multi1", "mkdir_p-multi2") do |path1, path2|
      FileUtils.mkdir_p([path1, path2]).should be_nil
      Dir.exists?(path1).should be_true
      Dir.exists?(path2).should be_true
      path3 = File.join({path1, "a", "b", "c"})
      path4 = File.join({path2, "a", "b", "c"})
      FileUtils.mkdir_p([path3, path4]).should be_nil
      Dir.exists?(path3).should be_true
      Dir.exists?(path4).should be_true
    end
  end

  it "tests mkdir_p with an existing path" do
    FileUtils.mkdir_p(datapath).should be_nil
    # FIXME: Refactor FileUtils.mkdir_p to remove leading './' in error message
    expect_raises_errno(Errno::EEXIST, "Unable to create directory './#{datapath("test_file.txt")}'") do
      FileUtils.mkdir_p(datapath("test_file.txt"))
    end
  end

  it "tests mkdir_p with multiple existing path" do
    FileUtils.mkdir_p([datapath, datapath]).should be_nil
    with_tempfile("mkdir_p-existing") do |path|
      # FIXME: Refactor FileUtils.mkdir_p to remove leading './' in error message
      expect_raises_errno(Errno::EEXIST, "Unable to create directory './#{datapath("test_file.txt")}'") do
        FileUtils.mkdir_p([datapath("test_file.txt"), path])
      end
    end
  end

  it "tests rmdir with an non existing path" do
    with_tempfile("rmdir-nonexisting") do |path|
      expect_raises_errno(Errno::ENOENT, "Unable to remove directory '#{path}'") do
        FileUtils.rmdir(path)
      end
    end
  end

  it "tests rmdir with multiple non existing path" do
    with_tempfile("rmdir-nonexisting") do |path|
      expect_raises_errno(Errno::ENOENT, "Unable to remove directory '#{path}1'") do
        FileUtils.rmdir(["#{path}1", "#{path}2"])
      end
    end
  end

  it "tests rmdir with a path that cannot be removed" do
    expect_raises_errno(Errno::ENOTEMPTY, "Unable to remove directory '#{datapath}'") do
      FileUtils.rmdir(datapath)
    end
  end

  it "tests rmdir with multiple path that cannot be removed" do
    expect_raises_errno(Errno::ENOTEMPTY, "Unable to remove directory '#{datapath}'") do
      FileUtils.rmdir([datapath, datapath])
    end
  end

  it "tests rm with an existing path" do
    with_tempfile("rm") do |path|
      File.write(path, "")
      FileUtils.rm(path).should be_nil
      File.exists?(path).should be_false
    end
  end

  it "tests rm with non existing path" do
    with_tempfile("rm-nonexistinent") do |path|
      expect_raises_errno(Errno::ENOENT, "Error deleting file '#{path}'") do
        FileUtils.rm(path)
      end
    end
  end

  it "tests rm with multiple existing paths" do
    with_tempfile("rm-multi1", "rm-multi2") do |path1, path2|
      File.write(path1, "")
      File.write(path2, "")
      FileUtils.rm([path1, path2]).should be_nil
      File.exists?(path1).should be_false
      File.exists?(path2).should be_false
    end
  end

  it "tests rm with some non existing paths" do
    with_tempfile("rm-nonexistent1", "rm-nonexistent2") do |path1, path2|
      File.write(path1, "")
      File.write(path2, "")

      expect_raises_errno(Errno::ENOENT, "Error deleting file '#{path2}'") do
        FileUtils.rm([path1, path2, path2])
      end
    end
  end

  describe "ln" do
    it "creates a hardlink" do
      path1 = "/tmp/crystal_ln_test_#{Process.pid}"
      path2 = "/tmp/crystal_ln_test_#{Process.pid + 1}"

      begin
        FileUtils.touch(path1)
        FileUtils.ln(path1, path2)
        File.exists?(path2).should be_true
        File.symlink?(path2).should be_false
      ensure
        FileUtils.rm_rf([path1, path2])
      end
    end

    it "creates a hardlink inside a destination dir" do
      path1 = "/tmp/crystal_ln_test_#{Process.pid}"
      path2 = "/tmp/crystal_ln_test_#{Process.pid + 1}/"
      path3 = File.join(path2, File.basename(path1))

      begin
        FileUtils.touch(path1)
        FileUtils.mkdir(path2)
        FileUtils.ln(path1, path2)
        File.exists?(path3).should be_true
        File.symlink?(path3).should be_false
      ensure
        FileUtils.rm_rf([path1, path2])
      end
    end

    it "creates multiple hardlinks inside a destination dir" do
      paths = Array.new(3) { |i| "/tmp/crystal_ln_test_#{Process.pid + i}" }
      dir_path = "/tmp/crystal_ln_test_#{Process.pid + 3}/"

      begin
        paths.each { |path| FileUtils.touch(path) }
        FileUtils.mkdir(dir_path)
        FileUtils.ln(paths, dir_path)

        paths.each do |path|
          link_path = File.join(dir_path, File.basename(path))
          File.exists?(link_path).should be_true
          File.symlink?(link_path).should be_false
        end
      ensure
        FileUtils.rm_rf(paths)
        FileUtils.rm_rf(dir_path)
      end
    end

    it "fails with a nonexistent source" do
      path1 = "/tmp/crystal_ln_test_#{Process.pid}"
      path2 = "/tmp/crystal_ln_test_#{Process.pid + 1}"

      ex = expect_raises_errno(Errno::ENOENT, "Error creating link from '#{path1}' to '#{path2}'") do
        FileUtils.ln(path1, path2)
      end
    end

    it "fails with an extant destination" do
      path1 = "/tmp/crystal_ln_test_#{Process.pid}"
      path2 = "/tmp/crystal_ln_test_#{Process.pid + 1}"

      begin
        FileUtils.touch([path1, path2])

        expect_raises_errno(Errno::EEXIST, "Error creating link from '#{path1}' to '#{path2}'") do
          FileUtils.ln(path1, path2)
        end
      ensure
        FileUtils.rm_rf([path1, path2])
      end
    end
  end

  describe "ln_s" do
    it "creates a symlink" do
      path1 = "/tmp/crystal_ln_s_test_#{Process.pid}"
      path2 = "/tmp/crystal_ln_s_test_#{Process.pid + 1}"

      begin
        FileUtils.touch(path1)
        FileUtils.ln_s(path1, path2)
        File.exists?(path2).should be_true
        File.symlink?(path2).should be_true
      ensure
        FileUtils.rm_rf([path1, path2])
      end
    end

    it "creates a symlink inside a destination dir" do
      path1 = "/tmp/crystal_ln_s_test_#{Process.pid}"
      path2 = "/tmp/crystal_ln_s_test_#{Process.pid + 1}/"
      path3 = File.join(path2, File.basename(path1))

      begin
        FileUtils.touch(path1)
        FileUtils.mkdir(path2)
        FileUtils.ln_s(path1, path2)
        File.exists?(path3).should be_true
        File.symlink?(path3).should be_true
      ensure
        FileUtils.rm_rf([path1, path2])
      end
    end

    it "creates multiple symlinks inside a destination dir" do
      paths = Array.new(3) { |i| "/tmp/crystal_ln_s_test_#{Process.pid + i}" }
      dir_path = "/tmp/crystal_ln_s_test_#{Process.pid + 3}/"

      begin
        paths.each { |path| FileUtils.touch(path) }
        FileUtils.mkdir(dir_path)
        FileUtils.ln_s(paths, dir_path)

        paths.each do |path|
          link_path = File.join(dir_path, File.basename(path))
          File.exists?(link_path).should be_true
          File.symlink?(link_path).should be_true
        end
      ensure
        FileUtils.rm_rf(paths)
        FileUtils.rm_rf(dir_path)
      end
    end

    it "works with a nonexistent source" do
      path1 = "/tmp/crystal_ln_s_test_#{Process.pid}"
      path2 = "/tmp/crystal_ln_s_test_#{Process.pid + 1}"

      begin
        FileUtils.ln_s(path1, path2)
        File.exists?(path2).should be_false
        File.symlink?(path2).should be_true

        expect_raises_errno(Errno::ENOENT, "Error resolving real path of '#{path2}'") do
          File.real_path(path2)
        end
      ensure
        FileUtils.rm_rf(path2)
      end
    end

    it "fails with an extant destination" do
      path1 = "/tmp/crystal_ln_s_test_#{Process.pid}"
      path2 = "/tmp/crystal_ln_s_test_#{Process.pid + 1}"

      begin
        FileUtils.touch([path1, path2])

        expect_raises_errno(Errno::EEXIST, "Error creating symlink from '#{path1}' to '#{path2}'") do
          FileUtils.ln_s(path1, path2)
        end
      ensure
        FileUtils.rm_rf([path1, path2])
      end
    end
  end

  describe "ln_sf" do
    it "overwrites a destination file" do
      path1 = "/tmp/crystal_ln_sf_test_#{Process.pid}"
      path2 = "/tmp/crystal_ln_sf_test_#{Process.pid + 1}"

      begin
        FileUtils.touch([path1, path2])
        File.symlink?(path1).should be_false
        File.symlink?(path2).should be_false

        FileUtils.ln_sf(path1, path2)
        File.symlink?(path1).should be_false
        File.symlink?(path2).should be_true
      ensure
        FileUtils.rm_rf([path1, path2])
      end
    end

    it "overwrites a destination file inside a dir" do
      dir = "/tmp/crystal_ln_sf_test_#{Process.pid}/"
      path1 = File.join(dir, "crystal_ln_sf_test_#{Process.pid + 1}")
      path2 = "/tmp/crystal_ln_sf_test_#{Process.pid + 1}"

      begin
        FileUtils.mkdir(dir)
        FileUtils.touch([path1, path2])
        File.symlink?(path1).should be_false
        File.symlink?(path2).should be_false

        FileUtils.ln_sf(path2, dir)
        File.symlink?(path1).should be_true
        File.symlink?(path2).should be_false
      ensure
        FileUtils.rm_rf([dir, path2])
      end
    end

    it "creates multiple symlinks in a destination dir, with overwrites" do
      dir = "/tmp/crystal_ln_sf_test_#{Process.pid + 3}"
      paths1 = Array.new(3) { |i| "crystal_ln_sf_test_#{Process.pid + i}" }
      paths2 = paths1.map { |p| File.join("/tmp/", p) }
      paths3 = paths1.map { |p| File.join(dir, p) }

      begin
        FileUtils.mkdir(dir)
        FileUtils.touch(paths2 + paths3)
        (paths2 + paths3).each { |p| File.symlink?(p).should be_false }

        FileUtils.ln_sf(paths2, dir)
        paths2.each { |p| File.symlink?(p).should be_false }
        paths3.each { |p| File.symlink?(p).should be_true }
      ensure
        FileUtils.rm_rf(paths2)
        FileUtils.rm_rf(dir)
      end
    end

    it "creates a symlink even if there's nothing to overwrite" do
      path1 = "/tmp/crystal_ln_sf_test_#{Process.pid}"
      path2 = "/tmp/crystal_ln_sf_test_#{Process.pid + 1}"

      begin
        FileUtils.touch(path1)
        File.exists?(path2).should be_false

        FileUtils.ln_sf(path1, path2)
        File.symlink?(path2).should be_true
      ensure
        FileUtils.rm_rf([path1, path2])
      end
    end
  end
end
