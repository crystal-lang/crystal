require "./spec_helper"
require "../support/errno"

private def it_raises_on_null_byte(operation, &block)
  it "errors on #{operation}" do
    expect_raises(ArgumentError, "String contains null byte") do
      block.call
    end
  end
end

describe "Dir" do
  it "tests exists? on existing directory" do
    Dir.exists?(datapath).should be_true
  end

  it "tests exists? on existing file" do
    Dir.exists?(datapath("dir", "f1.txt")).should be_false
  end

  it "tests exists? on nonexistent directory" do
    Dir.exists?(datapath("foo", "bar")).should be_false
  end

  it "tests exists? on a directory path to a file" do
    Dir.exists?(datapath("dir", "f1.txt", "/")).should be_false
  end

  describe "empty?" do
    it "tests empty? on a full directory" do
      Dir.empty?(datapath).should be_false
    end

    it "tests empty? on an empty directory" do
      with_tempfile "empty_directory" do |path|
        Dir.mkdir(path, 0o700)
        Dir.empty?(path).should be_true
      end
    end

    it "tests empty? on nonexistent directory" do
      expect_raises_errno(Errno::ENOENT, "Error determining size of '#{datapath("foo", "bar")}'") do
        Dir.empty?(datapath("foo", "bar"))
      end
    end

    # TODO: do we even want this?
    pending_win32 "tests empty? on a directory path to a file" do
      expect_raises_errno(Errno::ENOTDIR, "Error determining size of '#{datapath("dir", "f1.txt", "/")}'") do
        Dir.empty?(datapath("dir", "f1.txt", "/"))
      end
    end
  end

  it "tests mkdir and rmdir with a new path" do
    with_tempfile("mkdir") do |path|
      Dir.mkdir(path, 0o700)
      Dir.exists?(path).should be_true
      Dir.rmdir(path)
      Dir.exists?(path).should be_false
    end
  end

  it "tests mkdir with an existing path" do
    expect_raises_errno(Errno::EEXIST, "Unable to create directory '#{datapath}'") do
      Dir.mkdir(datapath, 0o700)
    end
  end

  it "tests mkdir_p with a new path" do
    with_tempfile("mkdir_p") do |path|
      Dir.mkdir_p(path)
      Dir.exists?(path).should be_true
      path = File.join(path, "a", "b", "c")
      Dir.mkdir_p(path)
      Dir.exists?(path).should be_true
    end
  end

  it "tests mkdir_p with an existing path" do
    Dir.mkdir_p(datapath)
    # FIXME: Refactor Dir#mkdir_p to remove leading `./` in error message
    expect_raises_errno(Errno::EEXIST, "Unable to create directory './#{datapath("dir", "f1.txt")}'") do
      Dir.mkdir_p(datapath("dir", "f1.txt"))
    end
  end

  it "tests rmdir with an nonexistent path" do
    with_tempfile("nonexistant") do |path|
      expect_raises_errno(Errno::ENOENT, "Unable to remove directory '#{path}'") do
        Dir.rmdir(path)
      end
    end
  end

  it "tests rmdir with a path that cannot be removed" do
    expect_raises_errno(Errno::ENOTEMPTY, "Unable to remove directory '#{datapath}'") do
      Dir.rmdir(datapath)
    end
  end

  describe "glob" do
    it "tests glob with a single pattern" do
      Dir["#{datapath}/dir/*.txt"].sort.should eq [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
      ].sort
    end

    it "tests glob with multiple patterns" do
      Dir["#{datapath}/dir/*.txt", "#{datapath}/dir/subdir/*.txt"].sort.should eq [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir", "f1.txt"),
      ].sort
    end

    it "tests glob with a single pattern with block" do
      result = [] of String
      Dir.glob("#{datapath}/dir/*.txt") do |filename|
        result << filename
      end
      result.sort.should eq([
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
      ].sort)
    end

    it "tests a recursive glob" do
      Dir["#{datapath}/dir/**/*.txt"].sort.should eq [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir", "f1.txt"),
        datapath("dir", "subdir", "subdir2", "f2.txt"),
      ].sort
    end

    it "tests a recursive glob with '?'" do
      Dir["#{datapath}/dir/f?.tx?"].sort.should eq [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "f3.txx"),
      ].sort
    end

    it "tests a recursive glob with alternation" do
      Dir["#{datapath}/{dir,dir/subdir}/*.txt"].sort.should eq [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir", "f1.txt"),
      ].sort
    end

    it "tests a glob with recursion inside alternation" do
      Dir["#{datapath}/dir/{**/*.txt,**/*.txx}"].sort.should eq [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "f3.txx"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir", "f1.txt"),
        datapath("dir", "subdir", "subdir2", "f2.txt"),
      ].sort
    end

    it "tests a recursive glob with nested alternations" do
      Dir["#{datapath}/dir/{?1.*,{f,g}2.txt}"].sort.should eq [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
      ].sort
    end

    it "tests with *" do
      Dir["#{datapath}/dir/*"].sort.should eq [
        datapath("dir", "dots"),
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "f3.txx"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir"),
        datapath("dir", "subdir2"),
      ].sort
    end

    it "tests with ** (same as *)" do
      Dir["#{datapath}/dir/**"].sort.should eq [
        datapath("dir", "dots"),
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "f3.txx"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir"),
        datapath("dir", "subdir2"),
      ].sort
    end

    it "tests with */" do
      Dir["#{datapath}/dir/*/"].sort.should eq [
        datapath("dir", "dots", ""),
        datapath("dir", "subdir", ""),
        datapath("dir", "subdir2", ""),
      ].sort
    end

    it "tests glob with a single pattern with extra slashes" do
      Dir["spec/std////data////dir////*.txt"].sort.should eq [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
      ].sort
    end

    it "tests with relative path" do
      Dir["#{datapath}/dir/*/"].sort.should eq [
        datapath("dir", "dots", ""),
        datapath("dir", "subdir", ""),
        datapath("dir", "subdir2", ""),
      ].sort
    end

    it "tests with relative path (starts with .)" do
      Dir["./#{datapath}/dir/*/"].sort.should eq [
        File.join(".", "spec", "std", "data", "dir", "dots", ""),
        File.join(".", "spec", "std", "data", "dir", "subdir", ""),
        File.join(".", "spec", "std", "data", "dir", "subdir2", ""),
      ].sort
    end

    it "tests with relative path (starts with ..)" do
      Dir.cd(datapath) do
        base_path = "../data/dir"
        Dir["#{base_path}/*/"].sort.should eq [
          File.join(base_path, "dots", ""),
          File.join(base_path, "subdir", ""),
          File.join(base_path, "subdir2", ""),
        ].sort
      end
    end

    # TODO: This spec is broken on win32 because of `raise` weirdness on windows
    pending_win32 "tests with relative path starting recursive" do
      Dir["**/dir/*/"].sort.should eq [
        datapath("dir", "dots", ""),
        datapath("dir", "subdir", ""),
        datapath("dir", "subdir2", ""),
      ].sort
    end

    it "matches symlinks" do
      link = datapath("f1_link.txt")
      non_link = datapath("non_link.txt")

      File.symlink(datapath("dir", "f1.txt"), link)
      File.symlink(datapath("dir", "nonexisting"), non_link)

      begin
        Dir["#{datapath}/*_link.txt"].sort.should eq [
          datapath("f1_link.txt"),
          datapath("non_link.txt"),
        ].sort
        Dir["#{datapath}/non_link.txt"].should eq [datapath("non_link.txt")]
      ensure
        File.delete link
        File.delete non_link
      end
    end

    it "empty pattern" do
      Dir[""].should eq [] of String
    end

    pending_win32 "root pattern" do
      Dir["/"].should eq ["/"]
    end

    it "pattern ending with .." do
      Dir["#{datapath}/dir/.."].sort.should eq [
        datapath("dir", ".."),
      ]
    end

    it "pattern ending with */.." do
      Dir["#{datapath}/dir/*/.."].sort.should eq [
        datapath("dir", "dots", ".."),
        datapath("dir", "subdir", ".."),
        datapath("dir", "subdir2", ".."),
      ]
    end

    it "pattern ending with ." do
      Dir["#{datapath}/dir/."].sort.should eq [
        datapath("dir", "."),
      ]
    end

    it "pattern ending with */." do
      Dir["#{datapath}/dir/*/."].sort.should eq [
        datapath("dir", "dots", "."),
        datapath("dir", "subdir", "."),
        datapath("dir", "subdir2", "."),
      ]
    end

    context "match_hidden: true" do
      it "matches hidden files" do
        Dir.glob("#{datapath}/dir/dots/**/*", match_hidden: true).sort.should eq [
          datapath("dir", "dots", ".dot.hidden"),
          datapath("dir", "dots", ".hidden"),
          datapath("dir", "dots", ".hidden", "f1.txt"),
        ].sort
      end
    end
  end

  describe "cd" do
    it "should work" do
      cwd = Dir.current
      Dir.cd("..")
      Dir.current.should_not eq(cwd)
      Dir.cd(cwd)
      Dir.current.should eq(cwd)
    end

    it "raises" do
      expect_raises_errno(Errno::ENOENT, "Error while changing directory to '/nope'") do
        Dir.cd("/nope")
      end
    end

    it "accepts a block" do
      cwd = Dir.current

      Dir.cd("..") do
        Dir.current.should_not eq(cwd)
      end

      Dir.current.should eq(cwd)
    end
  end

  describe ".tempdir" do
    it "returns default directory for tempfiles" do
      old_tmpdir = ENV["TMPDIR"]?
      ENV.delete("TMPDIR")
      Dir.tempdir.should eq("/tmp")
    ensure
      ENV["TMPDIR"] = old_tmpdir
    end

    it "returns configure directory for tempfiles" do
      old_tmpdir = ENV["TMPDIR"]?
      ENV["TMPDIR"] = "/my/tmp"
      Dir.tempdir.should eq("/my/tmp")
    ensure
      ENV["TMPDIR"] = old_tmpdir
    end
  end

  it "opens with new" do
    filenames = [] of String

    dir = Dir.new(datapath("dir"))
    dir.each do |filename|
      filenames << filename
    end.should be_nil
    dir.close

    filenames.includes?("f1.txt").should be_true
  end

  it "opens with open" do
    filenames = [] of String

    Dir.open(datapath("dir")) do |dir|
      dir.each do |filename|
        filenames << filename
      end.should be_nil
    end

    filenames.includes?("f1.txt").should be_true
  end

  it "lists entries" do
    filenames = Dir.entries(datapath("dir"))
    filenames.includes?(".").should be_true
    filenames.includes?("..").should be_true
    filenames.includes?("f1.txt").should be_true
  end

  it "lists children" do
    Dir.children(datapath("dir")).should eq(Dir.entries(datapath("dir")) - %w(. ..))
  end

  it "does to_s" do
    Dir.new(datapath("dir")).to_s.should eq("#<Dir:#{datapath("dir")}>")
  end

  it "gets dir iterator" do
    filenames = [] of String

    iter = Dir.new(datapath("dir")).each
    iter.each do |filename|
      filenames << filename
    end

    filenames.includes?(".").should be_true
    filenames.includes?("..").should be_true
    filenames.includes?("f1.txt").should be_true
  end

  it "gets child iterator" do
    filenames = [] of String

    iter = Dir.new(datapath("dir")).each_child
    iter.each do |filename|
      filenames << filename
    end

    filenames.includes?(".").should be_false
    filenames.includes?("..").should be_false
    filenames.includes?("f1.txt").should be_true
  end

  it "double close doesn't error" do
    dir = Dir.open(datapath("dir")) do |dir|
      dir.close
      dir.close
    end
  end

  describe "raises on null byte" do
    it_raises_on_null_byte "new" do
      Dir.new("foo\0bar")
    end

    it_raises_on_null_byte "cd" do
      Dir.cd("foo\0bar")
    end

    it_raises_on_null_byte "exists?" do
      Dir.exists?("foo\0bar")
    end

    it_raises_on_null_byte "mkdir" do
      Dir.mkdir("foo\0bar")
    end

    it_raises_on_null_byte "mkdir_p" do
      Dir.mkdir_p("foo\0bar")
    end

    it_raises_on_null_byte "rmdir" do
      Dir.rmdir("foo\0bar")
    end
  end
end
