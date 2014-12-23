require "spec"

def base
  Dir.working_directory
end

def tmpdir
  "/tmp"
end

def rootdir
  "/"
end

def home
  ENV["HOME"]
end

describe "File" do
  it "gets path" do
    path = "#{__DIR__}/data/test_file.txt"
    file = File.new path
    file.path.should eq(path)
  end

  it "reads entire file" do
    str = File.read "#{__DIR__}/data/test_file.txt"
    str.should eq("Hello World\n" * 20)
  end

  it "reads lines from file" do
    lines = File.read_lines "#{__DIR__}/data/test_file.txt"
    lines.length.should eq(20)
    lines.first.should eq("Hello World\n")
  end

  it "reads lines from file with each" do
    idx = 0
    File.each_line("#{__DIR__}/data/test_file.txt") do |line|
      if idx == 0
        line.should eq("Hello World\n")
      end
      idx += 1
    end
    idx.should eq(20)
  end

  describe "exists?" do
    it "gives true" do
      File.exists?("#{__DIR__}/data/test_file.txt").should be_true
    end

    it "gives false" do
      File.exists?("#{__DIR__}/data/non_existing_file.txt").should be_false
    end
  end

  describe "file?" do
    it "gives true" do
      File.file?("#{__DIR__}/data/test_file.txt").should be_true
    end

    it "gives false" do
      File.file?("#{__DIR__}/data").should be_false
    end
  end

  describe "directory?" do
    it "gives true" do
      File.directory?("#{__DIR__}/data").should be_true
    end

    it "gives false" do
      File.directory?("#{__DIR__}/data/test_file.txt").should be_false
    end
  end

  it "gets dirname" do
    File.dirname("/Users/foo/bar.cr").should eq("/Users/foo")
    File.dirname("foo").should eq(".")
    File.dirname("").should eq(".")
  end

  it "gets basename" do
    File.basename("/foo/bar/baz.cr").should eq("baz.cr")
    File.basename("/foo/").should eq("foo")
    File.basename("foo").should eq("foo")
    File.basename("").should eq("")
  end

  it "gets basename removing suffix" do
    File.basename("/foo/bar/baz.cr", ".cr").should eq("baz")
  end

  it "gets extname" do
    File.extname("/foo/bar/baz.cr").should eq(".cr")
    File.extname("/foo/bar/baz.cr.cz").should eq(".cz")
    File.extname("/foo/bar/.profile").should eq("")
    File.extname("/foo/bar/.profile.sh").should eq(".sh")
    File.extname("/foo/bar/foo.").should eq("")
    File.extname("test").should eq("")
  end

  it "constructs a path from parts" do
    File.join(["///foo", "bar"]).should eq("/foo/bar")
    File.join(["///foo", "//bar"]).should eq("/foo/bar")
    File.join(["foo", "bar", "baz"]).should eq("foo/bar/baz")
    File.join(["foo", "//bar//", "baz///"]).should eq("foo/bar/baz/")
    File.join(["/foo/", "/bar/", nil, "/baz/"]).should eq("/foo/bar/baz/")
  end

  it "gets stat for this file" do
    stat = File.stat(__FILE__)
    stat.blockdev?.should be_false
    stat.chardev?.should be_false
    stat.directory?.should be_false
    stat.file?.should be_true
  end

  it "gets stat for this directory" do
    stat = File.stat(__DIR__)
    stat.blockdev?.should be_false
    stat.chardev?.should be_false
    stat.directory?.should be_true
    stat.file?.should be_false
  end

  it "gets stat for a character device" do
    stat = File.stat("/dev/null")
    stat.blockdev?.should be_false
    stat.chardev?.should be_true
    stat.directory?.should be_false
    stat.file?.should be_false
  end

  it "gets stat for open file" do
    File.open(__FILE__, "r") do |file|
      stat = file.stat
      stat.blockdev?.should be_false
      stat.chardev?.should be_false
      stat.directory?.should be_false
      stat.file?.should be_true
    end
  end

  it "gets stat for non-existent file and raises" do
    expect_raises Errno do
      File.stat("non-existent")
    end
  end

  describe "size" do
    assert { File.size("#{__DIR__}/data/test_file.txt").should eq(240) }
    assert do
      File.open("#{__DIR__}/data/test_file.txt", "r") do |file|
        file.size.should eq(240)
      end
    end
  end

  describe "delete" do
    it "deletes a file" do
      filename = "#{__DIR__}/data/temp1.txt"
      File.open(filename, "w") {}
      File.exists?(filename).should be_true
      File.delete(filename)
      File.exists?(filename).should be_false
    end

    it "raises errno when file doesn't exist" do
      filename = "#{__DIR__}/data/temp1.txt"
      expect_raises Errno do
        File.delete(filename)
      end
    end
  end

  describe "rename" do
    it "renames a file" do
      filename = "#{__DIR__}/data/temp1.txt"
      filename2 = "#{__DIR__}/data/temp2.txt"
      File.open(filename, "w") { |f| f.puts "hello" }
      File.rename(filename, filename2)
      File.exists?(filename).should be_false
      File.exists?(filename2).should be_true
      File.read(filename2).strip.should eq("hello")
      File.delete(filename2)
    end

    it "raises if old file doesn't exist" do
      filename = "#{__DIR__}/data/temp1.txt"
      expect_raises Errno do
        File.rename(filename, "#{filename}.new")
      end
    end
  end

  describe "expand_path" do
    it "converts a pathname to an absolute pathname" do
      File.expand_path("").should eq(base)
      File.expand_path("a").should eq(File.join([base, "a"]))
      File.expand_path("a", nil).should eq(File.join([base, "a"]))
    end

    it "converts a pathname to an absolute pathname, Ruby-Talk:18512" do
      File.expand_path(".a").should eq(File.join([base, ".a"]))
      File.expand_path("..a").should eq(File.join([base, "..a"]))
      File.expand_path("a../b").should eq(File.join([base, "a../b"]))
    end

    it "keeps trailing dots on absolute pathname" do
      File.expand_path("a.").should eq(File.join([base, "a."]))
      File.expand_path("a..").should eq(File.join([base, "a.."]))
    end

    it "converts a pathname to an absolute pathname, using a complete path" do
      File.expand_path("", "#{tmpdir}").should eq("#{tmpdir}")
      File.expand_path("a", "#{tmpdir}").should eq("#{tmpdir}/a")
      File.expand_path("../a", "#{tmpdir}/xxx").should eq("#{tmpdir}/a")
      File.expand_path(".", "#{rootdir}").should eq("#{rootdir}")
    end

    it "expands a path with multi-byte characters" do
      File.expand_path("Ångström").should eq("#{base}/Ångström")
    end

    it "expands /./dir to /dir" do
      File.expand_path("/./dir").should eq("/dir")
    end

    it "replaces multiple / with a single /" do
      File.expand_path("////some/path").should eq("/some/path")
      File.expand_path("/some////path").should eq( "/some/path")
    end

    it "expand path with" do
      File.expand_path("../../bin", "/tmp/x").should eq("/bin")
      File.expand_path("../../bin", "/tmp").should eq("/bin")
      File.expand_path("../../bin", "/").should eq("/bin")
      File.expand_path("../bin", "tmp/x").should eq(File.join([base, "tmp", "bin"]))
      File.expand_path("../bin", "x/../tmp").should eq(File.join([base, "bin"]))
    end

    it "expand_path for commoms unix path  give a full path" do
      File.expand_path("/tmp/").should eq("/tmp")
      File.expand_path("/tmp/../../../tmp").should eq("/tmp")
      File.expand_path("").should eq(base)
      File.expand_path("./////").should eq(base)
      File.expand_path(".").should eq(base)
      File.expand_path(base).should eq(base)
    end

    it "converts a pathname to an absolute pathname, using ~ (home) as base" do
      File.expand_path("~/").should eq(home)
      File.expand_path("~/..badfilename").should eq("#{home}/..badfilename")
      File.expand_path("..").should eq(base.split("/")[0...-1].join("/"))
      File.expand_path("~/a","~/b").should eq("#{home}/a")
      File.expand_path("~").should eq(home)
      File.expand_path("~", "/tmp/gumby/ddd").should eq(home)
      File.expand_path("~/a", "/tmp/gumby/ddd").should eq(File.join([home, "a"]))
    end
  end

  it "writes" do
    filename = "#{__DIR__}/data/temp_write.txt"
    File.write(filename, "hello")
    File.read(filename).strip.should eq("hello")
    File.delete(filename)
  end
end
