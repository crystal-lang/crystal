require "./spec_helper"
require "file_utils"

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
      expect_raises(File::NotFoundError, "Error while changing directory: '/nope'") do
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
  end

  describe "touch" do
    it "creates file if it doesn't exist" do
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

    pending_win32 "copies permissions" do
      with_tempfile("cp-permissions-src.txt", "cp-permissions-out.txt") do |src_path, out_path|
        File.write(src_path, "foo")
        File.chmod(src_path, 0o700)

        FileUtils.cp(src_path, out_path)

        File.info(out_path).permissions.should eq(File::Permissions.new(0o700))
        FileUtils.cmp(src_path, out_path).should be_true
      end
    end

    it "raises an error if the directory doesn't exist" do
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

    it "copies a directory recursively if destination exists leaving existing files" do
      with_tempfile("cp_r-test", "cp_r-test-copied") do |src_path, dest_path|
        Dir.mkdir_p(dest_path)
        File.write(File.join(dest_path, "d"), "")

        Dir.mkdir_p(src_path)
        File.write(File.join(src_path, "a"), "")
        Dir.mkdir(File.join(src_path, "b"))
        File.write(File.join(src_path, "b/c"), "")

        FileUtils.cp_r(src_path, dest_path)
        File.exists?(File.join(dest_path, "a")).should be_true
        File.exists?(File.join(dest_path, "b/c")).should be_true
        File.exists?(File.join(dest_path, "d")).should be_true
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

    pending_win32 "doesn't follow symlinks" do
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
      with_tempfile("rm_rf-nonexistent") do |path|
        FileUtils.rm_rf(path).should be_nil
      end
    end

    it "doesn't return error on non existing files" do
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
      with_tempfile("mv-nonexistent") do |path|
        expect_raises(File::NotFoundError, "Error renaming file: '#{File.join(path, "a").inspect_unquoted}' -> '#{File.join(path, "b").inspect_unquoted}'") do
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
    expect_raises(File::AlreadyExistsError, "Unable to create directory: '#{datapath.inspect_unquoted}'") do
      Dir.mkdir(datapath, 0o700)
    end
  end

  it "tests mkdir with multiples existing paths" do
    expect_raises(File::AlreadyExistsError, "Unable to create directory: '#{datapath.inspect_unquoted}'") do
      FileUtils.mkdir([datapath, datapath], 0o700)
    end

    with_tempfile("mkdir-nonexistent") do |path|
      expect_raises(File::AlreadyExistsError, "Unable to create directory: '#{datapath.inspect_unquoted}'") do
        FileUtils.mkdir([path, datapath], 0o700)
      end
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

  it "tests mkdir_p with multiple existing path" do
    FileUtils.mkdir_p([datapath, datapath]).should be_nil
    with_tempfile("mkdir_p-existing") do |path|
      expect_raises(File::AlreadyExistsError, "Unable to create directory: '#{datapath("test_file.txt").inspect_unquoted}'") do
        FileUtils.mkdir_p([datapath("test_file.txt"), path])
      end
    end
  end

  it "tests rmdir with an non existing path" do
    with_tempfile("rmdir-nonexistent") do |path|
      expect_raises(File::NotFoundError, "Unable to remove directory: '#{path.inspect_unquoted}'") do
        FileUtils.rmdir(path)
      end
    end
  end

  it "tests rmdir with multiple non existing path" do
    with_tempfile("rmdir-nonexistent") do |path|
      expect_raises(File::NotFoundError, "Unable to remove directory: '#{path.inspect_unquoted}1'") do
        FileUtils.rmdir(["#{path}1", "#{path}2"])
      end
    end
  end

  it "tests rmdir with a path that cannot be removed" do
    expect_raises(File::Error, "Unable to remove directory: '#{datapath.inspect_unquoted}'") do
      FileUtils.rmdir(datapath)
    end
  end

  it "tests rmdir with multiple path that cannot be removed" do
    expect_raises(File::Error, "Unable to remove directory: '#{datapath.inspect_unquoted}'") do
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
    with_tempfile("rm-nonexistent") do |path|
      expect_raises(File::NotFoundError, "Error deleting file: '#{path.inspect_unquoted}'") do
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

      expect_raises(File::NotFoundError, "Error deleting file: '#{path2.inspect_unquoted}'") do
        FileUtils.rm([path1, path2, path2])
      end
    end
  end

  describe "ln" do
    it "creates a hardlink" do
      with_tempfile("ln_src", "ln_dst") do |path1, path2|
        FileUtils.touch(path1)
        FileUtils.ln(path1, path2)
        File.exists?(path2).should be_true
        File.symlink?(path2).should be_false
      end
    end

    it "creates a hardlink inside a destination dir" do
      with_tempfile("ln_src", "ln_dst_dir") do |path1, path2|
        path2 += File::SEPARATOR
        path3 = File.join(path2, File.basename(path1))
        FileUtils.touch(path1)
        FileUtils.mkdir(path2)
        FileUtils.ln(path1, path2)
        File.exists?(path3).should be_true
        File.symlink?(path3).should be_false
      end
    end

    it "creates multiple hardlinks inside a destination dir" do
      with_tempfile("ln_src_1", "ln_src_2", "ln_src_3", "ln_dst_dir") do |path1, path2, path3, dir_path|
        paths = [path1, path2, path3]
        dir_path += File::SEPARATOR

        paths.each { |path| FileUtils.touch(path) }
        FileUtils.mkdir(dir_path)
        FileUtils.ln(paths, dir_path)

        paths.each do |path|
          link_path = File.join(dir_path, File.basename(path))
          File.exists?(link_path).should be_true
          File.symlink?(link_path).should be_false
        end
      end
    end

    it "fails with a nonexistent source" do
      with_tempfile("ln_src_missing", "ln_dst_missing") do |path1, path2|
        ex = expect_raises(File::NotFoundError, "Error creating link: '#{path1.inspect_unquoted}' -> '#{path2.inspect_unquoted}'") do
          FileUtils.ln(path1, path2)
        end
      end
    end

    it "fails with an extant destination" do
      with_tempfile("ln_src", "ln_dst_exists") do |path1, path2|
        FileUtils.touch([path1, path2])

        expect_raises(File::AlreadyExistsError, "Error creating link: '#{path1.inspect_unquoted}' -> '#{path2.inspect_unquoted}'") do
          FileUtils.ln(path1, path2)
        end
      end
    end
  end

  describe "ln_s" do
    it "creates a symlink" do
      with_tempfile("ln_s_src", "ln_s_dst") do |path1, path2|
        FileUtils.touch(path1)
        FileUtils.ln_s(path1, path2)
        File.exists?(path2).should be_true
        File.symlink?(path2).should be_true
      end
    end

    it "creates a symlink inside a destination dir" do
      with_tempfile("ln_s_src", "ln_s_dst_dir") do |path1, path2|
        path3 = File.join(path2, File.basename(path1))

        FileUtils.touch(path1)
        FileUtils.mkdir(path2)
        FileUtils.ln_s(path1, path2)
        File.exists?(path3).should be_true
        File.symlink?(path3).should be_true
      end
    end

    it "creates multiple symlinks inside a destination dir" do
      with_tempfile("ln_s_src_1", "ln_s_src_2", "ln_s_src_3", "ln_s_dst_dir") do |path1, path2, path3, dir_path|
        paths = [path1, path2, path3]
        dir_path += File::SEPARATOR
        paths.each { |path| FileUtils.touch(path) }
        FileUtils.mkdir(dir_path)
        FileUtils.ln_s(paths, dir_path)

        paths.each do |path|
          link_path = File.join(dir_path, File.basename(path))
          File.exists?(link_path).should be_true
          File.symlink?(link_path).should be_true
        end
      end
    end

    pending_win32 "works with a nonexistent source" do
      with_tempfile("ln_s_src_missing", "ln_s_dst_missing") do |path1, path2|
        FileUtils.ln_s(path1, path2)
        File.exists?(path2).should be_false
        File.symlink?(path2).should be_true

        expect_raises(File::NotFoundError, "Error resolving real path: '#{path2.inspect_unquoted}'") do
          File.real_path(path2)
        end
      end
    end

    it "fails with an extant destination" do
      with_tempfile("ln_s_src", "ln_s_dst_exists") do |path1, path2|
        FileUtils.touch([path1, path2])

        expect_raises(File::AlreadyExistsError, "Error creating symlink: '#{path1.inspect_unquoted}' -> '#{path2.inspect_unquoted}'") do
          FileUtils.ln_s(path1, path2)
        end
      end
    end
  end

  describe "ln_sf" do
    it "overwrites a destination file" do
      with_tempfile("ln_sf_src", "ln_sf_dst_exists") do |path1, path2|
        FileUtils.touch([path1, path2])
        File.symlink?(path1).should be_false
        File.symlink?(path2).should be_false

        FileUtils.ln_sf(path1, path2)
        File.symlink?(path1).should be_false
        File.symlink?(path2).should be_true
      end
    end

    it "overwrites a destination file inside a dir" do
      with_tempfile("ln_sf_dst_dir", "ln_sf_dst") do |dir, path2|
        dir += File::SEPARATOR
        path1 = File.join(dir, File.basename(path2))

        FileUtils.mkdir(dir)
        FileUtils.touch([path1, path2])
        File.symlink?(path1).should be_false
        File.symlink?(path2).should be_false

        FileUtils.ln_sf(path2, dir)
        File.symlink?(path1).should be_true
        File.symlink?(path2).should be_false
      end
    end

    it "creates multiple symlinks in a destination dir, with overwrites" do
      with_tempfile("ln_sf_src_dir", "ln_sf_dst_dir") do |src_dir, dir|
        paths1 = Array.new(3) { |i| "exists_#{i}" }
        paths2 = paths1.map { |p| File.join(src_dir, p) }
        paths3 = paths1.map { |p| File.join(dir, p) }

        FileUtils.mkdir(src_dir)
        FileUtils.mkdir(dir)
        FileUtils.touch(paths2 + paths3)
        (paths2 + paths3).each { |p| File.symlink?(p).should be_false }

        FileUtils.ln_sf(paths2, dir)
        paths2.each { |p| File.symlink?(p).should be_false }
        paths3.each { |p| File.symlink?(p).should be_true }
      end
    end

    it "creates a symlink even if there's nothing to overwrite" do
      with_tempfile("ln_sf_src", "ln_sf_dst") do |path1, path2|
        FileUtils.touch(path1)
        File.exists?(path2).should be_false

        FileUtils.ln_sf(path1, path2)
        File.symlink?(path2).should be_true
      end
    end
  end
end
