require "spec"

private def it_raises_on_null_byte(operation, &block)
  it "errors on #{operation}" do
    expect_raises(ArgumentError, "String contains null byte") do
      block.call
    end
  end
end

describe "Dir" do
  it "tests exists? on existing directory" do
    Dir.exists?(File.join([__DIR__, "../"])).should be_true
  end

  it "tests exists? on existing file" do
    Dir.exists?(__FILE__).should be_false
  end

  it "tests exists? on nonexistent directory" do
    Dir.exists?(File.join([__DIR__, "/foo/bar/"])).should be_false
  end

  it "tests exists? on a directory path to a file" do
    Dir.exists?("#{__FILE__}/").should be_false
  end

  describe "empty?" do
    it "tests empty? on a full directory" do
      Dir.empty?(File.join([__DIR__, "../"])).should be_false
    end

    it "tests empty? on an empty directory" do
      path = "/tmp/crystal_empty_test_#{Process.pid}/"
      Dir.mkdir(path, 0o700)
      Dir.empty?(path).should be_true
    end

    it "tests empty? on nonexistent directory" do
      expect_raises(Errno, /Error determining size of/) do
        Dir.empty?(File.join([__DIR__, "/foo/bar/"]))
      end
    end

    it "tests empty? on a directory path to a file" do
      ex = expect_raises(Errno, /Error determining size of/) do
        Dir.empty?("#{__FILE__}/")
      end
      ex.errno.should eq(Errno::ENOTDIR)
    end
  end

  it "tests mkdir and rmdir with a new path" do
    path = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    Dir.mkdir(path, 0o700)
    Dir.exists?(path).should be_true
    Dir.rmdir(path)
    Dir.exists?(path).should be_false
  end

  it "tests mkdir with an existing path" do
    expect_raises Errno do
      Dir.mkdir(__DIR__, 0o700)
    end
  end

  it "tests mkdir_p with a new path" do
    path = "/tmp/crystal_mkdir_ptest_#{Process.pid}/"
    Dir.mkdir_p(path)
    Dir.exists?(path).should be_true
    path = File.join({path, "a", "b", "c"})
    Dir.mkdir_p(path)
    Dir.exists?(path).should be_true
  end

  it "tests mkdir_p with an existing path" do
    Dir.mkdir_p(__DIR__)
    expect_raises Errno do
      Dir.mkdir_p(__FILE__)
    end
  end

  it "tests rmdir with an nonexistent path" do
    expect_raises Errno do
      Dir.rmdir("/tmp/crystal_mkdir_test_#{Process.pid}/")
    end
  end

  it "tests rmdir with a path that cannot be removed" do
    expect_raises Errno do
      Dir.rmdir(__DIR__)
    end
  end

  describe "glob" do
    it "tests glob with a single pattern" do
      Dir["#{__DIR__}/data/dir/*.txt"].sort.should eq [
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "g2.txt"),
      ].sort
    end

    it "tests glob with multiple patterns" do
      Dir["#{__DIR__}/data/dir/*.txt", "#{__DIR__}/data/dir/subdir/*.txt"].sort.should eq [
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "g2.txt"),
        File.join(__DIR__, "data", "dir", "subdir", "f1.txt"),
      ].sort
    end

    it "tests glob with a single pattern with block" do
      result = [] of String
      Dir.glob("#{__DIR__}/data/dir/*.txt") do |filename|
        result << filename
      end
      result.sort.should eq([
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "g2.txt"),
      ].sort)
    end

    it "tests a recursive glob" do
      Dir["#{__DIR__}/data/dir/**/*.txt"].sort.should eq [
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "g2.txt"),
        File.join(__DIR__, "data", "dir", "subdir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "subdir", "subdir2", "f2.txt"),
      ].sort
    end

    it "tests a recursive glob with '?'" do
      Dir["#{__DIR__}/data/dir/f?.tx?"].sort.should eq [
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "f3.txx"),
      ].sort
    end

    it "tests a recursive glob with alternation" do
      Dir["#{__DIR__}/data/{dir,dir/subdir}/*.txt"].sort.should eq [
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "g2.txt"),
        File.join(__DIR__, "data", "dir", "subdir", "f1.txt"),
      ].sort
    end

    it "tests a glob with recursion inside alternation" do
      Dir["#{__DIR__}/data/dir/{**/*.txt,**/*.txx}"].sort.should eq [
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "f3.txx"),
        File.join(__DIR__, "data", "dir", "g2.txt"),
        File.join(__DIR__, "data", "dir", "subdir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "subdir", "subdir2", "f2.txt"),
      ].sort
    end

    it "tests a recursive glob with nested alternations" do
      Dir["#{__DIR__}/data/dir/{?1.*,{f,g}2.txt}"].sort.should eq [
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "g2.txt"),
      ].sort
    end

    it "tests with *" do
      Dir["#{__DIR__}/data/dir/*"].sort.should eq [
        File.join(__DIR__, "data", "dir", "dots"),
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "f3.txx"),
        File.join(__DIR__, "data", "dir", "g2.txt"),
        File.join(__DIR__, "data", "dir", "subdir"),
        File.join(__DIR__, "data", "dir", "subdir2"),
      ].sort
    end

    it "tests with ** (same as *)" do
      Dir["#{__DIR__}/data/dir/**"].sort.should eq [
        File.join(__DIR__, "data", "dir", "dots"),
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "f3.txx"),
        File.join(__DIR__, "data", "dir", "g2.txt"),
        File.join(__DIR__, "data", "dir", "subdir"),
        File.join(__DIR__, "data", "dir", "subdir2"),
      ].sort
    end

    it "tests with */" do
      Dir["#{__DIR__}/data/dir/*/"].sort.should eq [
        File.join(__DIR__, "data", "dir", "dots", ""),
        File.join(__DIR__, "data", "dir", "subdir", ""),
        File.join(__DIR__, "data", "dir", "subdir2", ""),
      ].sort
    end

    it "tests glob with a single pattern with extra slashes" do
      Dir["#{__DIR__}////data////dir////*.txt"].sort.should eq [
        File.join(__DIR__, "data", "dir", "f1.txt"),
        File.join(__DIR__, "data", "dir", "f2.txt"),
        File.join(__DIR__, "data", "dir", "g2.txt"),
      ].sort
    end

    it "tests with relative path" do
      Dir["spec/std/data/dir/*/"].sort.should eq [
        File.join("spec", "std", "data", "dir", "dots", ""),
        File.join("spec", "std", "data", "dir", "subdir", ""),
        File.join("spec", "std", "data", "dir", "subdir2", ""),
      ].sort
    end

    it "tests with relative path (starts with .)" do
      Dir["./spec/std/data/dir/*/"].sort.should eq [
        File.join(".", "spec", "std", "data", "dir", "dots", ""),
        File.join(".", "spec", "std", "data", "dir", "subdir", ""),
        File.join(".", "spec", "std", "data", "dir", "subdir2", ""),
      ].sort
    end

    it "tests with relative path (starts with ..)" do
      base_path = File.join("..", File.basename(File.dirname(File.dirname(__DIR__))), "spec", "std", "data", "dir")
      Dir["../#{File.basename(File.dirname(File.dirname(__DIR__)))}/spec/std/data/dir/*/"].sort.should eq [
        File.join(base_path, "dots", ""),
        File.join(base_path, "subdir", ""),
        File.join(base_path, "subdir2", ""),
      ].sort
    end

    it "tests with relative path starting recursive" do
      Dir["**/dir/*/"].sort.should eq [
        File.join("spec", "std", "data", "dir", "dots", ""),
        File.join("spec", "std", "data", "dir", "subdir", ""),
        File.join("spec", "std", "data", "dir", "subdir2", ""),
      ].sort
    end

    it "matches symlinks" do
      link = File.join(__DIR__, "data", "f1_link.txt")
      non_link = File.join(__DIR__, "data", "non_link.txt")

      File.symlink(File.join(__DIR__, "data", "dir", "f1.txt"), link)
      File.symlink(File.join(__DIR__, "data", "dir", "nonexisting"), non_link)

      begin
        Dir["#{__DIR__}/data/*_link.txt"].sort.should eq [
          File.join(__DIR__, "data", "f1_link.txt"),
          File.join(__DIR__, "data", "non_link.txt"),
        ].sort
      ensure
        File.delete link
        File.delete non_link
      end
    end

    it "empty pattern" do
      Dir[""].should eq [] of String
    end

    it "root pattern" do
      Dir["/"].should eq [
        {% if flag?(:windows) %}
          "C:\\"
        {% else %}
          "/"
        {% end %},
      ]
    end

    it "pattern ending with .." do
      Dir["#{__DIR__}/data/dir/.."].sort.should eq [
        File.join(__DIR__, "data", "dir", ".."),
      ]
    end

    it "pattern ending with */.." do
      Dir["#{__DIR__}/data/dir/*/.."].sort.should eq [
        File.join(__DIR__, "data", "dir", "dots", ".."),
        File.join(__DIR__, "data", "dir", "subdir", ".."),
        File.join(__DIR__, "data", "dir", "subdir2", ".."),
      ]
    end

    it "pattern ending with ." do
      Dir["#{__DIR__}/data/dir/."].sort.should eq [
        File.join(__DIR__, "data", "dir", "."),
      ]
    end

    it "pattern ending with */." do
      Dir["#{__DIR__}/data/dir/*/."].sort.should eq [
        File.join(__DIR__, "data", "dir", "dots", "."),
        File.join(__DIR__, "data", "dir", "subdir", "."),
        File.join(__DIR__, "data", "dir", "subdir2", "."),
      ]
    end

    context "match_hidden: true" do
      it "matches hidden files" do
        Dir.glob("#{__DIR__}/data/dir/dots/**/*", match_hidden: true).sort.should eq [
          File.join(__DIR__, "data", "dir", "dots", ".dot.hidden"),
          File.join(__DIR__, "data", "dir", "dots", ".hidden"),
          File.join(__DIR__, "data", "dir", "dots", ".hidden", "f1.txt"),
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
      expect_raises(Errno, "No such file or directory") do
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

  it "opens with new" do
    filenames = [] of String

    dir = Dir.new(__DIR__)
    dir.each do |filename|
      filenames << filename
    end.should be_nil
    dir.close

    filenames.includes?("dir_spec.cr").should be_true
  end

  it "opens with open" do
    filenames = [] of String

    Dir.open(__DIR__) do |dir|
      dir.each do |filename|
        filenames << filename
      end.should be_nil
    end

    filenames.includes?("dir_spec.cr").should be_true
  end

  it "lists entries" do
    filenames = Dir.entries(__DIR__)
    filenames.includes?(".").should be_true
    filenames.includes?("..").should be_true
    filenames.includes?("dir_spec.cr").should be_true
  end

  it "lists children" do
    Dir.children(__DIR__).should eq(Dir.entries(__DIR__) - %w(. ..))
  end

  it "does to_s" do
    Dir.new(__DIR__).to_s.should eq("#<Dir:#{__DIR__}>")
  end

  it "gets dir iterator" do
    filenames = [] of String

    iter = Dir.new(__DIR__).each
    iter.each do |filename|
      filenames << filename
    end

    filenames.includes?(".").should be_true
    filenames.includes?("..").should be_true
    filenames.includes?("dir_spec.cr").should be_true
  end

  it "gets child iterator" do
    filenames = [] of String

    iter = Dir.new(__DIR__).each_child
    iter.each do |filename|
      filenames << filename
    end

    filenames.includes?(".").should be_false
    filenames.includes?("..").should be_false
    filenames.includes?("dir_spec.cr").should be_true
  end

  it "double close doesn't error" do
    dir = Dir.open(__DIR__) do |dir|
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
