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
end
