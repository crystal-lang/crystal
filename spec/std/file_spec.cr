require "spec"
require "tempfile"

private def base
  Dir.working_directory
end

private def tmpdir
  "/tmp"
end

private def rootdir
  "/"
end

private def home
  ENV["HOME"]
end

describe "File" do
  it "gets path" do
    path = "#{__DIR__}/data/test_file.txt"
    file = File.new path
    expect(file.path).to eq(path)
  end

  it "reads entire file" do
    str = File.read "#{__DIR__}/data/test_file.txt"
    expect(str).to eq("Hello World\n" * 20)
  end

  it "reads lines from file" do
    lines = File.read_lines "#{__DIR__}/data/test_file.txt"
    expect(lines.length).to eq(20)
    expect(lines.first).to eq("Hello World\n")
  end

  it "reads lines from file with each" do
    idx = 0
    File.each_line("#{__DIR__}/data/test_file.txt") do |line|
      if idx == 0
        expect(line).to eq("Hello World\n")
      end
      idx += 1
    end
    expect(idx).to eq(20)
  end

  describe "exists?" do
    it "gives true" do
      expect(File.exists?("#{__DIR__}/data/test_file.txt")).to be_true
    end

    it "gives false" do
      expect(File.exists?("#{__DIR__}/data/non_existing_file.txt")).to be_false
    end
  end

  describe "file?" do
    it "gives true" do
      expect(File.file?("#{__DIR__}/data/test_file.txt")).to be_true
    end

    it "gives false" do
      expect(File.file?("#{__DIR__}/data")).to be_false
    end
  end

  describe "directory?" do
    it "gives true" do
      expect(File.directory?("#{__DIR__}/data")).to be_true
    end

    it "gives false" do
      expect(File.directory?("#{__DIR__}/data/test_file.txt")).to be_false
    end
  end

  it "gets dirname" do
    expect(File.dirname("/Users/foo/bar.cr")).to eq("/Users/foo")
    expect(File.dirname("foo")).to eq(".")
    expect(File.dirname("")).to eq(".")
  end

  it "gets basename" do
    expect(File.basename("/foo/bar/baz.cr")).to eq("baz.cr")
    expect(File.basename("/foo/")).to eq("foo")
    expect(File.basename("foo")).to eq("foo")
    expect(File.basename("")).to eq("")
  end

  it "gets basename removing suffix" do
    expect(File.basename("/foo/bar/baz.cr", ".cr")).to eq("baz")
  end

  it "gets extname" do
    expect(File.extname("/foo/bar/baz.cr")).to eq(".cr")
    expect(File.extname("/foo/bar/baz.cr.cz")).to eq(".cz")
    expect(File.extname("/foo/bar/.profile")).to eq("")
    expect(File.extname("/foo/bar/.profile.sh")).to eq(".sh")
    expect(File.extname("/foo/bar/foo.")).to eq("")
    expect(File.extname("test")).to eq("")
  end

  it "constructs a path from parts" do
    expect(File.join(["///foo", "bar"])).to eq("///foo/bar")
    expect(File.join(["///foo", "//bar"])).to eq("///foo//bar")
    expect(File.join(["/foo/", "/bar"])).to eq("/foo/bar")
    expect(File.join(["foo", "bar", "baz"])).to eq("foo/bar/baz")
    expect(File.join(["foo", "//bar//", "baz///"])).to eq("foo//bar//baz///")
    expect(File.join(["/foo/", "/bar/", "/baz/"])).to eq("/foo/bar/baz/")
  end

  it "gets stat for this file" do
    stat = File.stat(__FILE__)
    expect(stat.blockdev?).to be_false
    expect(stat.chardev?).to be_false
    expect(stat.directory?).to be_false
    expect(stat.file?).to be_true
  end

  it "gets stat for this directory" do
    stat = File.stat(__DIR__)
    expect(stat.blockdev?).to be_false
    expect(stat.chardev?).to be_false
    expect(stat.directory?).to be_true
    expect(stat.file?).to be_false
  end

  it "gets stat for a character device" do
    stat = File.stat("/dev/null")
    expect(stat.blockdev?).to be_false
    expect(stat.chardev?).to be_true
    expect(stat.directory?).to be_false
    expect(stat.file?).to be_false
  end

  it "gets stat for open file" do
    File.open(__FILE__, "r") do |file|
      stat = file.stat
      expect(stat.blockdev?).to be_false
      expect(stat.chardev?).to be_false
      expect(stat.directory?).to be_false
      expect(stat.file?).to be_true
    end
  end

  it "gets stat for non-existent file and raises" do
    expect_raises Errno do
      File.stat("non-existent")
    end
  end

  it "gets stat mtime for new file" do
    tmp = Tempfile.new "tmp"
    begin
      expect((tmp.stat.atime - Time.utc_now).total_seconds).to be < 5
      expect((tmp.stat.ctime - Time.utc_now).total_seconds).to be < 5
      expect((tmp.stat.mtime - Time.utc_now).total_seconds).to be < 5
    ensure
      tmp.delete
    end
  end

  describe "size" do
    assert { expect(File.size("#{__DIR__}/data/test_file.txt")).to eq(240) }
    assert do
      File.open("#{__DIR__}/data/test_file.txt", "r") do |file|
        expect(file.size).to eq(240)
      end
    end
  end

  describe "delete" do
    it "deletes a file" do
      filename = "#{__DIR__}/data/temp1.txt"
      File.open(filename, "w") {}
      expect(File.exists?(filename)).to be_true
      File.delete(filename)
      expect(File.exists?(filename)).to be_false
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
      expect(File.exists?(filename)).to be_false
      expect(File.exists?(filename2)).to be_true
      expect(File.read(filename2).strip).to eq("hello")
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
      expect(File.expand_path("")).to eq(base)
      expect(File.expand_path("a")).to eq(File.join([base, "a"]))
      expect(File.expand_path("a", nil)).to eq(File.join([base, "a"]))
    end

    it "converts a pathname to an absolute pathname, Ruby-Talk:18512" do
      expect(File.expand_path(".a")).to eq(File.join([base, ".a"]))
      expect(File.expand_path("..a")).to eq(File.join([base, "..a"]))
      expect(File.expand_path("a../b")).to eq(File.join([base, "a../b"]))
    end

    it "keeps trailing dots on absolute pathname" do
      expect(File.expand_path("a.")).to eq(File.join([base, "a."]))
      expect(File.expand_path("a..")).to eq(File.join([base, "a.."]))
    end

    it "converts a pathname to an absolute pathname, using a complete path" do
      expect(File.expand_path("", "#{tmpdir}")).to eq("#{tmpdir}")
      expect(File.expand_path("a", "#{tmpdir}")).to eq("#{tmpdir}/a")
      expect(File.expand_path("../a", "#{tmpdir}/xxx")).to eq("#{tmpdir}/a")
      expect(File.expand_path(".", "#{rootdir}")).to eq("#{rootdir}")
    end

    it "expands a path with multi-byte characters" do
      expect(File.expand_path("Ångström")).to eq("#{base}/Ångström")
    end

    it "expands /./dir to /dir" do
      expect(File.expand_path("/./dir")).to eq("/dir")
    end

    it "replaces multiple / with a single /" do
      expect(File.expand_path("////some/path")).to eq("/some/path")
      expect(File.expand_path("/some////path")).to eq( "/some/path")
    end

    it "expand path with" do
      expect(File.expand_path("../../bin", "/tmp/x")).to eq("/bin")
      expect(File.expand_path("../../bin", "/tmp")).to eq("/bin")
      expect(File.expand_path("../../bin", "/")).to eq("/bin")
      expect(File.expand_path("../bin", "tmp/x")).to eq(File.join([base, "tmp", "bin"]))
      expect(File.expand_path("../bin", "x/../tmp")).to eq(File.join([base, "bin"]))
    end

    it "expand_path for commoms unix path  give a full path" do
      expect(File.expand_path("/tmp/")).to eq("/tmp")
      expect(File.expand_path("/tmp/../../../tmp")).to eq("/tmp")
      expect(File.expand_path("")).to eq(base)
      expect(File.expand_path("./////")).to eq(base)
      expect(File.expand_path(".")).to eq(base)
      expect(File.expand_path(base)).to eq(base)
    end

    it "converts a pathname to an absolute pathname, using ~ (home) as base" do
      expect(File.expand_path("~/")).to eq(home)
      expect(File.expand_path("~/..badfilename")).to eq("#{home}/..badfilename")
      expect(File.expand_path("..")).to eq(base.split("/")[0...-1].join("/"))
      expect(File.expand_path("~/a","~/b")).to eq("#{home}/a")
      expect(File.expand_path("~")).to eq(home)
      expect(File.expand_path("~", "/tmp/gumby/ddd")).to eq(home)
      expect(File.expand_path("~/a", "/tmp/gumby/ddd")).to eq(File.join([home, "a"]))
    end
  end

  it "writes" do
    filename = "#{__DIR__}/data/temp_write.txt"
    File.write(filename, "hello")
    expect(File.read(filename).strip).to eq("hello")
    File.delete(filename)
  end

  it "does to_s" do
    expect(File.new(__FILE__).to_s).to eq("#<File:#{__FILE__}>")
  end

  describe "close" do
    it "is not closed when opening" do
      file = File.new(__FILE__)
      expect(file.closed?).to be_false
    end

    it "is closed when closed" do
      file = File.new(__FILE__)
      file.close
      expect(file.closed?).to be_true
    end

    it "raises when closing twice" do
      file = File.new(__FILE__)
      file.close

      expect_raises IO::Error, /closed stream/ do
        file.close
      end
    end

    it "does to_s when closed" do
      file = File.new(__FILE__)
      file.close
      expect(file.to_s).to eq("#<File:#{__FILE__} (closed)>")
    end
  end
end
