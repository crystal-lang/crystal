require "spec"
require "path"

private def base
  Path.new(Dir.current)
end

private def tmpdir
  Path.new("/tmp")
end

private def rootdir
  Path.new("/")
end

private def home
  Path.new(ENV["HOME"])
end

describe "Path" do
  it "can be used by File" do
    File.read(Path.new("#{__DIR__}/data/test_file.txt"))
  end

  describe "#join" do
    it "constructs a path from parts" do
      Path.new("///foo").join(["bar"]).should eq(Path.new("///foo/bar"))
      Path.new("///foo").join(["//bar"]).should eq(Path.new("///foo//bar"))
      Path.new("/foo/").join(["/bar"]).should eq(Path.new("/foo/bar"))
      Path.new("foo").join(["bar", "baz"]).should eq(Path.new("foo/bar/baz"))
      Path.new("foo").join(["//bar//", "baz///"]).should eq(Path.new("foo//bar//baz///"))
      Path.new("/foo/").join(["/bar/", "/baz/"]).should eq(Path.new("/foo/bar/baz/"))

      (Path.new("foo") / "bar").should eq(Path.new("foo/bar"))
      (Path.new("foo") + "bar").should eq(Path.new("foo/bar"))
    end
  end

  describe "#dirname" do
    it "gets dirname" do
      Path.new("/Users/foo/bar.cr").dirname.should eq(Path.new("/Users/foo"))
      Path.new("foo").dirname.should eq(Path.new("."))
      Path.new("").dirname.should eq(Path.new("."))
    end
  end

  describe "#basename" do
    it "gets basename" do
      Path.new("/foo/bar/baz.cr").basename.should eq(Path.new("baz.cr"))
      Path.new("/foo/").basename.should eq(Path.new("foo"))
      Path.new("foo").basename.should eq(Path.new("foo"))
      Path.new("").basename.should eq(Path.new(""))
      Path.new("/").basename.should eq(Path.new("/"))
    end

    it "gets basename removing suffix" do
      Path.new("/foo/bar/baz.cr").basename(".cr").should eq(Path.new("baz"))
    end
  end

  describe "#extname" do
    it "gets extname" do
      Path.new("/foo/bar/baz.cr").extname.should eq(".cr")
      Path.new("/foo/bar/baz.cr.cz").extname.should eq(".cz")
      Path.new("/foo/bar/.profile").extname.should eq("")
      Path.new("/foo/bar/.profile.sh").extname.should eq(".sh")
      Path.new("/foo/bar/foo.").extname.should eq("")
      Path.new("test").extname.should eq("")
    end
  end

  describe "expand_path" do
    it "converts a pathname to an absolute pathname" do
      Path.new("").expand_path.should eq(base)
      Path.new("a").expand_path.should eq(base / "a")
      Path.new("a").expand_path(nil).should eq(base / "a")
    end

    it "converts a pathname to an absolute pathname, Ruby-Talk:18512" do
      Path.new(".a").expand_path.should eq(base / ".a")
      Path.new("..a").expand_path.should eq(base / "..a")
      Path.new("a../b").expand_path.should eq(base / "a../b")
    end

    it "keeps trailing dots on absolute pathname" do
      Path.new("a.").expand_path.should eq(base / "a.")
      Path.new("a..").expand_path.should eq(base / "a..")
    end

    it "converts a pathname to an absolute pathname, using a complete path" do
      Path.new("").expand_path(tmpdir).should eq(tmpdir)
      Path.new("a").expand_path(tmpdir).should eq(tmpdir / "a")
      Path.new("../a").expand_path(tmpdir / "xxx").should eq(tmpdir / "a")
      Path.new(".").expand_path(rootdir).should eq(rootdir)
    end

    it "expands a path with multi-byte characters" do
      Path.new("Ångström").expand_path.should eq(base / "Ångström")
    end

    it "expands /./dir to /dir" do
      Path.new("/./dir").expand_path.should eq(Path.new("/dir"))
    end

    it "replaces multiple / with a single /" do
      Path.new("////some/path").expand_path.should eq(Path.new("/some/path"))
      Path.new("/some////path").expand_path.should eq(Path.new("/some/path"))
    end

    it "expand path with" do
      Path.new("../../bin").expand_path("/tmp/x").should eq(Path.new("/bin"))
      Path.new("../../bin").expand_path("/tmp").should eq(Path.new("/bin"))
      Path.new("../../bin").expand_path("/").should eq(Path.new("/bin"))
      Path.new("../bin").expand_path("tmp/x").should eq(base / "tmp" / "bin")
      Path.new("../bin").expand_path("x/../tmp").should eq(base / "bin")
    end

    it "expand_path for commoms unix path  give a full path" do
      Path.new("/tmp/").expand_path.should eq(Path.new("/tmp"))
      Path.new("/tmp/../../../tmp").expand_path.should eq(Path.new("/tmp"))
      Path.new("").expand_path.should eq(base)
      Path.new("./////").expand_path.should eq(base)
      Path.new(".").expand_path.should eq(base)
      Path.new(base).expand_path.should eq(base)
    end

    it "converts a pathname to an absolute pathname, using ~ (home) as base" do
      Path.new("~/").expand_path.should eq(home)
      Path.new("~/..badfilename").expand_path.should eq(home / "..badfilename")
      Path.new("..").expand_path.should eq(Path.new("/#{base.to_s.split("/")[0...-1].join("/")}".gsub(%r{\A//}, "/")))
      Path.new("~/a").expand_path("~/b").should eq(home / "a")
      Path.new("~").expand_path.should eq(home)
      Path.new("~").expand_path("/tmp/gumby/ddd").should eq(home)
      Path.new("~/a").expand_path("/tmp/gumby/ddd").should eq(home / "a")
    end
  end
end
