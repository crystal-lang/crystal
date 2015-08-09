require "spec"

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

  it "tests mkdir and rmdir with a new path" do
    path = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    Dir.mkdir(path, 0o700).should eq(0)
    Dir.exists?(path).should be_true
    Dir.rmdir(path).should eq(0)
    Dir.exists?(path).should be_false
  end

  it "tests mkdir with an existing path" do
    expect_raises Errno do
      Dir.mkdir(__DIR__, 0o700)
    end
  end

  it "tests mkdir_p with a new path" do
    path = "/tmp/crystal_mkdir_ptest_#{Process.pid}/"
    Dir.mkdir_p(path).should eq(0)
    Dir.exists?(path).should be_true
    path = File.join({path, "a", "b", "c"})
    Dir.mkdir_p(path).should eq(0)
    Dir.exists?(path).should be_true
  end

  it "tests mkdir_p with an existing path" do
    Dir.mkdir_p(__DIR__).should eq(0)
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

  it "tests glob with a single pattern" do
    result = Dir["#{__DIR__}/*.cr"]
    Dir.foreach(__DIR__) do |file|
      next unless file.ends_with?(".cr")

      result.includes?(File.join(__DIR__, file)).should be_true
    end
  end

  it "tests glob with multiple patterns" do
    result = Dir["#{__DIR__}/*.cr", "#{__DIR__}/{io,html}/*.cr"]

    {__DIR__, "#{__DIR__}/io", "#{__DIR__}/html"}.each do |dir|
      Dir.foreach(dir) do |file|
        next unless file.ends_with?(".cr")
        result.includes?(File.join(dir, file)).should be_true
      end
    end
  end

  it "tests glob with a single pattern with block" do
    result = [] of String
    Dir.glob("#{__DIR__}/*.cr") do |filename|
      result << filename
    end

    Dir.foreach(__DIR__) do |file|
      next unless file.ends_with?(".cr")

      result.includes?(File.join(__DIR__, file)).should be_true
    end
  end

  describe "chdir" do
    it "should work" do
      cwd = Dir.working_directory
      Dir.chdir("..")
      Dir.working_directory.should_not eq(cwd)
      Dir.cd(cwd)
      Dir.working_directory.should eq(cwd)
    end

    it "raises" do
      expect_raises do
        Dir.chdir("/nope")
      end
    end

    it "accepts a block" do
      cwd = Dir.working_directory

      Dir.chdir("..") do
        Dir.working_directory.should_not eq(cwd)
      end

      Dir.working_directory.should eq(cwd)
    end
  end


# Temporary workaround for __FILE__ and __DIR__ not working in macros
DIR__ = __DIR__
FILE__ = __FILE__

{% if HAVE_OPENAT %}
  describe "openat" do
    it "tests exists? (at) on existing file" do
      dir = Dir.new(DIR__)
      dir.exists?(File.basename(FILE__)).should be_true
    end

    it "tests mkdirat and rmdirat with a new path" do
      dir = Dir.new("/tmp")
      path = "crystal_mkdir_test_#{Process.pid}/"
      dir.mkdir(path, 0o700).should eq(nil)
      dir.exists?(path).should be_true
      dir.rmdir(path).should eq(nil)
      dir.exists?(path).should be_false
    end

    it "tests mkdirat with an existing path" do
      dir = Dir.new(".")
      expect_raises Errno do
        dir.mkdir(".", 0o700)
      end
    end

    it "tests rmdirat with an nonexistent path" do
      dir = Dir.new("/tmp")
      expect_raises Errno do
        dir.rmdir("crystal_mkdir_test_#{Process.pid}/")
      end
    end

    it "tests rmdirat with a path that cannot be removed" do
      dir = Dir.new(DIR__)
      expect_raises Errno do
        dir.rmdir(DIR__)
      end
    end

    it "tests dir.open with an existing path and checks stat" do
      dir = Dir.new(File.dirname(DIR__))
      dir2 = dir.open(File.basename(DIR__))

      File.stat(FILE__).should eq(dir2.stat(File.basename(FILE__)))
      File.lstat(FILE__).should eq(dir2.lstat(File.basename(FILE__)))
    end

    it "tests dir.open_file" do
      dir = Dir.new(DIR__)
      file = dir.open_file(File.basename(FILE__))

      file.stat.should eq(File.stat(FILE__))
      file.read.should eq(File.read(FILE__))
    end

    it "renames a file" do
      filename = "temp1.txt"
      filename2 = "temp2.txt"
      dir = Dir.new(DIR__).open("data")
      dir.open_file(filename, "w") { |f| f.puts "hello" }
      dir.rename(filename, filename2)
      dir.exists?(filename).should be_false
      dir.exists?(filename2).should be_true
      dir.delete(filename2)
    end
  end
{% end %}

  it "opens with new" do
    filenames = [] of String

    dir = Dir.new(__DIR__)
    dir.each do |filename|
      filenames << filename
    end
    dir.close

    filenames.includes?("dir_spec.cr").should be_true
  end

  it "opens with open" do
    filenames = [] of String

    Dir.open(__DIR__) do |dir|
      dir.each do |filename|
        filenames << filename
      end
    end

    filenames.includes?("dir_spec.cr").should be_true
  end

  it "lists entries" do
    filenames = Dir.entries(__DIR__)
    filenames.includes?("dir_spec.cr").should be_true
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

    filenames.includes?("dir_spec.cr").should be_true
  end
end
