require "spec"
require "path"

describe "Path" do
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
end
