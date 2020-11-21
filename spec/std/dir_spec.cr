require "./spec_helper"

private def unset_tempdir
  {% if flag?(:windows) %}
    old_tempdirs = {ENV["TMP"]?, ENV["TEMP"]?, ENV["USERPROFILE"]?}
    begin
      ENV.delete("TMP")
      ENV.delete("TEMP")
      ENV.delete("USERPROFILE")

      yield
    ensure
      ENV["TMP"], ENV["TEMP"], ENV["USERPROFILE"] = old_tempdirs
    end
  {% else %}
    begin
      old_tempdir = ENV["TMPDIR"]?
      ENV.delete("TMPDIR")

      yield
    ensure
      ENV["TMPDIR"] = old_tempdir
    end
  {% end %}
end

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
      expect_raises(File::NotFoundError, "Error opening directory: '#{datapath("foo", "bar").inspect_unquoted}'") do
        Dir.empty?(datapath("foo", "bar"))
      end
    end

    # TODO: do we even want this?
    pending_win32 "tests empty? on a directory path to a file" do
      expect_raises(File::Error, "Error opening directory: '#{datapath("dir", "f1.txt", "/").inspect_unquoted}'") do
        Dir.empty?(datapath("dir", "f1.txt", "/"))
      end
    end
  end

  it "tests mkdir and delete with a new path" do
    with_tempfile("mkdir") do |path|
      Dir.mkdir(path, 0o700)
      Dir.exists?(path).should be_true
      Dir.delete(path)
      Dir.exists?(path).should be_false
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
    expect_raises(File::AlreadyExistsError, "Unable to create directory: '#{datapath.inspect_unquoted}'") do
      Dir.mkdir(datapath, 0o700)
    end
  end

  describe ".mkdir_p" do
    it "with a new path" do
      with_tempfile("mkdir_p-new") do |path|
        Dir.mkdir_p(path)
        Dir.exists?(path).should be_true
        path = File.join(path, "a", "b", "c")
        Dir.mkdir_p(path)
        Dir.exists?(path).should be_true
      end
    end

    context "path exists" do
      it "fails when path is a file" do
        expect_raises(File::AlreadyExistsError, "Unable to create directory: '#{datapath("test_file.txt").inspect_unquoted}': File exists") do
          Dir.mkdir_p(datapath("test_file.txt"))
        end
      end

      it "noop when path is a directory" do
        Dir.exists?(datapath("dir")).should be_true
        Dir.mkdir_p(datapath("dir"))
        Dir.exists?(datapath("dir")).should be_true
      end
    end
  end

  it "tests delete with an nonexistent path" do
    with_tempfile("nonexistent") do |path|
      expect_raises(File::NotFoundError, "Unable to remove directory: '#{path.inspect_unquoted}'") do
        Dir.delete(path)
      end
    end
  end

  it "tests delete with a path that cannot be removed" do
    expect_raises(File::Error, "Unable to remove directory: '#{datapath.inspect_unquoted}'") do
      Dir.delete(datapath)
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
        base_path = Path["..", "data", "dir"]
        Dir["#{base_path}/*/"].sort.should eq [
          base_path.join("dots", "").to_s,
          base_path.join("subdir", "").to_s,
          base_path.join("subdir2", "").to_s,
        ].sort
      end
    end

    it "tests with relative path starting recursive" do
      Dir["**/dir/*/"].sort.should eq [
        datapath("dir", "dots", ""),
        datapath("dir", "subdir", ""),
        datapath("dir", "subdir2", ""),
      ].sort
    end

    pending_win32 "matches symlinks" do
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

    it "root pattern" do
      {% if flag?(:windows) %}
        Dir["C:/"].should eq ["C:\\"]
      {% else %}
        Dir["/"].should eq ["/"]
      {% end %}
    end

    it "pattern ending with .." do
      Dir["#{datapath}/dir/.."].sort.should eq [
        datapath("dir", ".."),
      ].sort
    end

    it "pattern ending with */.." do
      Dir["#{datapath}/dir/*/.."].sort.should eq [
        datapath("dir", "dots", ".."),
        datapath("dir", "subdir", ".."),
        datapath("dir", "subdir2", ".."),
      ].sort
    end

    it "pattern ending with ." do
      Dir["#{datapath}/dir/."].sort.should eq [
        datapath("dir", "."),
      ].sort
    end

    it "pattern ending with */." do
      Dir["#{datapath}/dir/*/."].sort.should eq [
        datapath("dir", "dots", "."),
        datapath("dir", "subdir", "."),
        datapath("dir", "subdir2", "."),
      ].sort
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

    context "match_hidden: false" do
      it "ignores hidden files" do
        Dir.glob("#{datapath}/dir/dots/*", match_hidden: false).size.should eq 0
      end

      it "ignores hidden files recursively" do
        Dir.glob("#{datapath}/dir/dots/**/*", match_hidden: false).size.should eq 0
      end
    end

    context "with path" do
      expected = [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
      ]

      it "posix path" do
        Dir[Path.posix(datapath, "dir", "*.txt")].sort.should eq expected
        Dir[[Path.posix(datapath, "dir", "*.txt")]].sort.should eq expected
      end

      it "windows path" do
        Dir[Path.windows(datapath, "dir", "*.txt")].sort.should eq expected
        Dir[[Path.windows(datapath, "dir", "*.txt")]].sort.should eq expected
      end
    end
  end

  describe "cd" do
    it "accepts string" do
      cwd = Dir.current
      Dir.cd("..")
      Dir.current.should_not eq(cwd)
      Dir.cd(cwd)
      Dir.current.should eq(cwd)
    end

    it "accepts path" do
      cwd = Dir.current
      Dir.cd(Path.new(".."))
      Dir.current.should_not eq(cwd)
      Dir.cd(cwd)
      Dir.current.should eq(cwd)
    end

    it "raises" do
      expect_raises(File::NotFoundError, "Error while changing directory: '/nope'") do
        Dir.cd("/nope")
      end
    end

    it "accepts a block with path" do
      cwd = Dir.current

      Dir.cd(Path.new("..")) do
        Dir.current.should_not eq(cwd)
      end

      Dir.current.should eq(cwd)
    end

    it "accepts a block with string" do
      cwd = Dir.current

      Dir.cd("..") do
        Dir.current.should_not eq(cwd)
      end

      Dir.current.should eq(cwd)
    end
  end

  it ".current" do
    Dir.current.should eq(`#{{{ flag?(:win32) ? "cmd /c cd" : "pwd" }}}`.chomp)
  end

  describe ".tempdir" do
    it "returns default directory for tempfiles" do
      unset_tempdir do
        {% if flag?(:windows) %}
          # GetTempPathW defaults to the Windows directory when %TMP%, %TEMP%
          # and %USERPROFILE% are not set.
          # Without going further into the implementation details, simply
          # verifying that the directory exits is sufficient.
          Dir.exists?(Dir.tempdir).should be_true
        {% else %}
          # POSIX implementation is in Crystal::System::Dir and defaults to
          # `/tmp` when $TMPDIR is not set.
          Dir.tempdir.should eq "/tmp"
        {% end %}
      end
    end

    it "returns configure directory for tempfiles" do
      unset_tempdir do
        tmp_path = Path["my_temporary_path"].expand.to_s
        ENV[{{ flag?(:windows) ? "TMP" : "TMPDIR" }}] = tmp_path
        Dir.tempdir.should eq tmp_path
      end
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

  describe "#path" do
    it "returns init value" do
      path = datapath("dir")
      dir = Dir.new(path)
      dir.path.should eq path
    end
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

    it_raises_on_null_byte "delete" do
      Dir.delete("foo\0bar")
    end
  end
end
