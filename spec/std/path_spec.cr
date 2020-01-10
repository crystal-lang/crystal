require "spec"
require "./spec_helper"

private BASE_POSIX   = "/default/base"
private BASE_WINDOWS = "\\default\\base"
private HOME_WINDOWS = "C:\\Users\\Crystal"
private HOME_POSIX   = "/home/crystal"

private def it_normalizes_path(path, posix = path, windows = path, file = __FILE__, line = __LINE__)
  assert_paths(path, posix, windows, "normalizes", file, line, &.normalize)
end

private def it_expands_path(path, posix, windows = posix, *, base = nil, env_home = nil, expand_base = false, home = false, file = __FILE__, line = __LINE__)
  assert_paths(path, posix, windows, %((base: "#{base}")), file, line) do |path|
    prev_home = ENV["HOME"]?

    begin
      ENV["HOME"] = env_home || (path.windows? ? HOME_WINDOWS : HOME_POSIX)

      base_arg = base || (path.windows? ? BASE_WINDOWS : BASE_POSIX)
      path.expand(base_arg.not_nil!, expand_base: !!expand_base, home: home)
    ensure
      ENV["HOME"] = prev_home
    end
  end
end

private def it_joins_path(path, parts, posix, windows = posix, file = __FILE__, line = __LINE__)
  assert_paths(path, posix, windows, %(resolving "#{parts}"), file, line, &.join(parts))
end

private def assert_paths(path, posix, windows = posix, label = nil, file = __FILE__, line = __LINE__, &block : Path -> _)
  case posix
  when Nil
  when Tuple  then posix = Path.posix(*posix)
  when String then posix = Path.posix(posix)
  when Array  then posix = posix.map { |path| Path.posix(path) }
  end
  case windows
  when Nil
  when Tuple  then windows = Path.windows(*windows)
  when String then windows = Path.windows(windows)
  when Array  then windows = windows.map { |path| Path.windows(path) }
  end
  assert_paths_raw(path, posix, windows, label, file, line, &block)
end

private def assert_paths_raw(path, posix, windows = posix, label = nil, file = __FILE__, line = __LINE__, &block : Path -> _)
  it %(#{label} "#{path}" (posix)), file, line do
    block.call(Path.posix(path)).should eq(posix)
  end
  it %(#{label} "#{path}" (windows)), file, line do
    block.call(Path.windows(path)).should eq(windows)
  end
end

describe Path do
  describe ".new" do
    it { Path.new("foo").native?.should be_true }
    it { Path.new("foo").to_s.should eq "foo" }

    it "fails with null byte" do
      expect_raises ArgumentError, "String contains null byte" do
        Path.new("foo\0")
      end
    end

    it { Path.new.to_s.should eq "" }
  end

  describe ".posix" do
    it { Path.posix("foo").posix?.should be_true }
    it { Path.posix("foo").windows?.should be_false }
    it { Path.posix("foo").to_s.should eq "foo" }

    it "fails with null byte" do
      expect_raises ArgumentError, "String contains null byte" do
        Path.posix("foo\0")
      end
    end

    it { Path.posix.to_s.should eq "" }
  end

  describe ".windows" do
    it { Path.windows("foo").posix?.should be_false }
    it { Path.windows("foo").windows?.should be_true }
    it { Path.windows("foo").to_s.should eq "foo" }

    it "fails with null byte" do
      expect_raises ArgumentError, "String contains null byte" do
        Path.windows("foo\0")
      end
    end

    it { Path.windows.to_s.should eq "" }
  end

  it ".[]" do
    Path["foo"].should eq Path.new("foo")
    Path["foo"].native?.should be_true
    Path["foo", "bar", "baz"].should eq Path.new("foo", "bar", "baz")
    Path["/foo", "bar", "baz"].should eq Path.new("/foo", "bar", "baz")
  end

  describe "#parent" do
    assert_paths("/Users/foo/bar.cr", "/Users/foo", &.parent)
    assert_paths("Users/foo/bar.cr", "Users/foo", &.parent)
    assert_paths("foo/bar/", "foo", &.parent)
    assert_paths("foo/bar/.", "foo/bar", &.parent)
    assert_paths("foo/bar/..", "foo/bar", &.parent)
    assert_paths("foo", ".", &.parent)
    assert_paths("foo/", ".", &.parent)
    assert_paths("/", "/", &.parent)
    assert_paths("/.", "/", &.parent)
    assert_paths("////", "/", &.parent)
    assert_paths("foo//.//", "foo", &.parent)
    assert_paths("/.", "/", &.parent)
    assert_paths("/foo", "/", &.parent)
    assert_paths("", ".", &.parent)
    assert_paths("./foo", ".", &.parent)
    assert_paths(".", ".", &.parent)
    assert_paths("\\Users\\foo\\bar.cr", ".", "\\Users\\foo", &.parent)
    assert_paths("\\Users/foo\\bar.cr", "\\Users", "\\Users/foo", &.parent)
    assert_paths("foo\\bar\\", ".", "foo", &.parent)
    assert_paths("foo\\bar\\.", ".", "foo\\bar", &.parent)
    assert_paths("foo\\bar\\..", ".", "foo\\bar", &.parent)
    assert_paths("foo\\", ".", &.parent)
    assert_paths("\\", ".", "\\", &.parent)
    assert_paths("\\.", ".", "\\", &.parent)
    assert_paths(".\\foo", ".", &.parent)
    assert_paths("C:", ".", "C:", &.parent)
    assert_paths("C:/", ".", "C:/", &.parent)
    assert_paths("C:\\", ".", "C:\\", &.parent)
    assert_paths("C:/foo", "C:", "C:/", &.parent)
    assert_paths("C:\\foo", ".", "C:\\", &.parent)
    assert_paths("/foo/C:/bar", "/foo/C:", "/foo/C:", &.parent)
  end

  describe "#parents" do
    assert_paths("/Users/foo/bar.cr", ["/", "/Users", "/Users/foo"], &.parents)
    assert_paths("Users/foo/bar.cr", [".", "Users", "Users/foo"], &.parents)
    assert_paths("foo/bar/", [".", "foo"], &.parents)
    assert_paths("foo/bar/.", [".", "foo", "foo/bar"], &.parents)
    assert_paths("foo", ["."], &.parents)
    assert_paths("foo/", ["."], &.parents)
    assert_paths("/", [] of String, &.parents)
    assert_paths("////", [] of String, &.parents)
    assert_paths("/.", ["/"], &.parents)
    assert_paths("/foo", ["/"], &.parents)
    assert_paths("", [] of String, &.parents)
    assert_paths("./foo", ["."], &.parents)
    assert_paths(".", [] of String, &.parents)
    assert_paths("\\Users\\foo\\bar.cr", ["."], ["\\", "\\Users", "\\Users\\foo"], &.parents)
    assert_paths("\\Users/foo\\bar.cr", [".", "\\Users"], ["\\", "\\Users", "\\Users/foo"], &.parents)
    assert_paths("C:\\Users\\foo\\bar.cr", ["."], ["C:\\", "C:\\Users", "C:\\Users\\foo"], &.parents)
    assert_paths("foo\\bar\\", ["."], [".", "foo"], &.parents)
    assert_paths("foo\\", ["."], &.parents)
    assert_paths("\\", ["."], [] of String, &.parents)
    assert_paths(".\\foo", ["."], &.parents)
    assert_paths("foo/../bar/", [".", "foo", "foo/.."], &.parents)
    assert_paths("foo/../bar/.", [".", "foo", "foo/..", "foo/../bar"], &.parents)
    assert_paths("foo/bar/..", [".", "foo", "foo/bar"], &.parents)
    assert_paths("foo/bar/../.", [".", "foo", "foo/bar", "foo/bar/.."], &.parents)
    assert_paths("foo/./bar/", [".", "foo", "foo/."], &.parents)
    assert_paths("foo/./bar/.", [".", "foo", "foo/.", "foo/./bar"], &.parents)
    assert_paths("foo/bar/.", [".", "foo", "foo/bar"], &.parents)
    assert_paths("foo/bar/./.", [".", "foo", "foo/bar", "foo/bar/."], &.parents)
    assert_paths("m/.gitignore", [".", "m"], &.parents)
    assert_paths("m", ["."], &.parents)
    assert_paths("m/", ["."], &.parents)
    assert_paths("m//", ["."], &.parents)
    assert_paths("m//a/b", [".", "m", "m//a"], &.parents)
    assert_paths("/m", ["/"], &.parents)
    assert_paths("/m/", ["/"], &.parents)
    assert_paths("C:", ["."], [] of String, &.parents)
    assert_paths("C:/", ["."], [] of String, &.parents)
    assert_paths("C:\\", ["."], [] of String, &.parents)
    assert_paths("C:folder", ["."], ["C:"], &.parents)
    assert_paths("C:\\folder", ["."], ["C:\\"], &.parents)
    assert_paths("C:\\\\folder", ["."], ["C:\\\\"], &.parents)
    assert_paths("C:\\.", ["."], ["C:\\"], &.parents)
  end

  describe "#dirname" do
    assert_paths_raw("/Users/foo/bar.cr", "/Users/foo", &.dirname)
    assert_paths_raw("foo", ".", &.dirname)
    assert_paths_raw("foo/", ".", &.dirname)
    assert_paths_raw("/foo", "/", &.dirname)
    assert_paths_raw("/foo/", "/", &.dirname)
    assert_paths_raw("/foo//", "/", &.dirname)
    assert_paths_raw("m/.gitignore", "m", &.dirname)
    assert_paths_raw("m/", ".", &.dirname)
    assert_paths_raw("m//", ".", &.dirname)
    assert_paths_raw("m//a/b", "m//a", &.dirname)
    assert_paths_raw("m", ".", &.dirname)
    assert_paths_raw("/m", "/", &.dirname)
    assert_paths_raw("/m/", "/", &.dirname)
    assert_paths_raw("C:", ".", "C:", &.dirname)
    assert_paths_raw("C:/", ".", "C:/", &.dirname)
    assert_paths_raw("C:\\", ".", "C:\\", &.dirname)
  end

  describe "#basename" do
    assert_paths_raw("/foo/bar/baz.cr", "baz.cr", &.basename)
    assert_paths_raw("/foo/", "foo", &.basename)
    assert_paths_raw("foo", "foo", &.basename)
    assert_paths_raw("x", "x", &.basename)
    assert_paths_raw("", "", &.basename)
    assert_paths_raw(".", ".", &.basename)
    assert_paths_raw("/.", ".", &.basename)
    assert_paths_raw("/", "/", &.basename)
    assert_paths_raw("////", "/", &.basename)
    assert_paths_raw("a/x", "x", &.basename)
    assert_paths_raw("a/.x", ".x", &.basename)
    assert_paths_raw("a/x.", "x.", &.basename)

    assert_paths_raw("\\foo\\bar\\baz.cr", "\\foo\\bar\\baz.cr", "baz.cr", &.basename)
    assert_paths_raw("\\foo\\", "\\foo\\", "foo", &.basename)
    assert_paths_raw("\\", "\\", "\\", &.basename)
    assert_paths_raw("\\.", "\\.", ".", &.basename)

    describe "removes suffix" do
      assert_paths_raw("/foo/bar/baz.cr", "baz", &.basename(".cr"))
      assert_paths_raw("\\foo\\bar\\baz.cr", "\\foo\\bar\\baz", "baz", &.basename(".cr"))
      assert_paths_raw("\\foo/bar\\baz.cr", "bar\\baz", "baz", &.basename(".cr"))
      assert_paths_raw("/foo/bar/baz.cr.tmp", "baz.cr.tmp", "baz.cr.tmp", &.basename(".cr"))
      assert_paths_raw("\\foo\\bar\\baz.cr.tmp", "\\foo\\bar\\baz.cr.tmp", "baz.cr.tmp", &.basename(".cr"))
      assert_paths_raw("/foo/bar/baz.cr.tmp", "baz", &.basename(".cr.tmp"))
      assert_paths_raw("\\foo\\bar\\baz.cr.tmp", "\\foo\\bar\\baz", "baz", &.basename(".cr.tmp"))
      assert_paths_raw("/foo/bar/baz.cr.tmp", "baz.cr", &.basename(".tmp"))
      assert_paths_raw("\\foo\\bar\\baz.cr.tmp", "\\foo\\bar\\baz.cr", "baz.cr", &.basename(".tmp"))
      assert_paths_raw("a.txt", "a", &.basename(".txt"))
      assert_paths_raw("a.x", "a", &.basename(".x"))
    end
  end

  describe "#parts" do
    assert_paths_raw("/Users/foo/bar.cr", ["/", "Users", "foo", "bar.cr"], &.parts)
    assert_paths_raw("Users/foo/bar.cr", ["Users", "foo", "bar.cr"], &.parts)
    assert_paths_raw("foo/bar/", ["foo", "bar"], &.parts)
    assert_paths_raw("foo/bar/.", ["foo", "bar", "."], &.parts)
    assert_paths_raw("foo", ["foo"], &.parts)
    assert_paths_raw("foo/", ["foo"], &.parts)
    assert_paths_raw("/", ["/"], &.parts)
    assert_paths_raw("////", ["////"], &.parts)
    assert_paths_raw("/.", ["/", "."], &.parts)
    assert_paths_raw("/foo", ["/", "foo"], &.parts)
    assert_paths_raw("", [] of String, &.parts)
    assert_paths_raw("./foo", [".", "foo"], &.parts)
    assert_paths_raw(".", ["."], &.parts)
    assert_paths_raw("\\Users\\foo\\bar.cr", ["\\Users\\foo\\bar.cr"], ["\\", "Users", "foo", "bar.cr"], &.parts)
    assert_paths_raw("\\Users/foo\\bar.cr", ["\\Users", "foo\\bar.cr"], ["\\", "Users", "foo", "bar.cr"], &.parts)
    assert_paths_raw("C:\\Users\\foo\\bar.cr", ["C:\\Users\\foo\\bar.cr"], ["C:\\", "Users", "foo", "bar.cr"], &.parts)
    assert_paths_raw("\\\\some\\share\\", ["\\\\some\\share\\"], ["\\\\some\\share\\"], &.parts)
    assert_paths_raw("\\\\some\\share", ["\\\\some\\share"], &.parts)
    assert_paths_raw("\\\\some\\share\\bar.cr", ["\\\\some\\share\\bar.cr"], ["\\\\some\\share\\", "bar.cr"], &.parts)
    assert_paths_raw("//some/share", ["//", "some", "share"], ["//some/share"], &.parts)
    assert_paths_raw("//some/share/", ["//", "some", "share"], ["//some/share/"], &.parts)
    assert_paths_raw("//some/share/bar.cr", ["//", "some", "share", "bar.cr"], ["//some/share/", "bar.cr"], &.parts)
    assert_paths_raw("foo\\bar\\", ["foo\\bar\\"], ["foo", "bar"], &.parts)
    assert_paths_raw("foo\\", ["foo\\"], ["foo"], &.parts)
    assert_paths_raw("\\", ["\\"], ["\\"], &.parts)
    assert_paths_raw(".\\foo", [".\\foo"], [".", "foo"], &.parts)
    assert_paths_raw("foo/../bar/", ["foo", "..", "bar"], &.parts)
    assert_paths_raw("foo/../bar/.", ["foo", "..", "bar", "."], &.parts)
    assert_paths_raw("foo/bar/..", ["foo", "bar", ".."], &.parts)
    assert_paths_raw("foo/bar/../.", ["foo", "bar", "..", "."], &.parts)
    assert_paths_raw("foo/./bar/", ["foo", ".", "bar"], &.parts)
    assert_paths_raw("foo/./bar/.", ["foo", ".", "bar", "."], &.parts)
    assert_paths_raw("foo/bar/.", ["foo", "bar", "."], &.parts)
    assert_paths_raw("foo/bar/./.", ["foo", "bar", ".", "."], &.parts)
    assert_paths_raw("m/.gitignore", ["m", ".gitignore"], &.parts)
    assert_paths_raw("m", ["m"], &.parts)
    assert_paths_raw("m/", ["m"], &.parts)
    assert_paths_raw("m//", ["m"], &.parts)
    assert_paths_raw("m\\", ["m\\"], ["m"], &.parts)
    assert_paths_raw("m//a/b", ["m", "a", "b"], &.parts)
    assert_paths_raw("m\\a/b", ["m\\a", "b"], ["m", "a", "b"], &.parts)
    assert_paths_raw("/m", ["/", "m"], &.parts)
    assert_paths_raw("/m/", ["/", "m"], &.parts)
    assert_paths_raw("C:", ["C:"], &.parts)
    assert_paths_raw("C:/", ["C:"], ["C:/"], &.parts)
    assert_paths_raw("C:\\", ["C:\\"], &.parts)
    assert_paths_raw("C:folder", ["C:folder"], ["C:", "folder"], &.parts)
    assert_paths_raw("C:\\folder", ["C:\\folder"], ["C:\\", "folder"], &.parts)
    assert_paths_raw("C:\\\\folder", ["C:\\\\folder"], ["C:\\\\", "folder"], &.parts)
    assert_paths_raw("C:\\.", ["C:\\."], ["C:\\", "."], &.parts)
  end

  describe "#extension" do
    assert_paths_raw("/foo/bar/baz.cr", ".cr", &.extension)
    assert_paths_raw("/foo/bar/baz.cr.cz", ".cz", &.extension)
    assert_paths_raw("/foo/bar/.profile", "", &.extension)
    assert_paths_raw("/foo/bar/.profile.sh", ".sh", &.extension)
    assert_paths_raw("/foo/bar/foo.", "", &.extension)
    assert_paths_raw("test", "", &.extension)
    assert_paths_raw("test.ext/foo", "", &.extension)
  end

  describe "#absolute?" do
    assert_paths_raw("/foo", true, false, &.absolute?)
    assert_paths_raw("/./foo", true, false, &.absolute?)

    assert_paths_raw("foo", false, &.absolute?)
    assert_paths_raw("./foo", false, &.absolute?)
    assert_paths_raw("~/foo", false, &.absolute?)

    assert_paths_raw("\\foo", false, &.absolute?)
    assert_paths_raw("\\.\\foo", false, &.absolute?)
    assert_paths_raw("foo", false, &.absolute?)
    assert_paths_raw(".\\foo", false, &.absolute?)
    assert_paths_raw("~\\foo", false, &.absolute?)
    assert_paths_raw("C:", false, &.absolute?)

    assert_paths_raw("C:\\foo", false, true, &.absolute?)
    assert_paths_raw("C:/foo/bar", false, true, &.absolute?)
    assert_paths_raw("C:\\", false, true, &.absolute?)
    assert_paths_raw("C:/foo", false, true, &.absolute?)
    assert_paths_raw("C:/", false, true, &.absolute?)
    assert_paths_raw("c:\\\\", false, true, &.absolute?)

    assert_paths_raw("//some/share", true, false, &.absolute?)
    assert_paths_raw("\\\\some\\share", false, false, &.absolute?)
    assert_paths_raw("//some/share/", true, true, &.absolute?)
    assert_paths_raw("\\\\some\\share\\", false, true, &.absolute?)
  end

  describe "#drive" do
    assert_paths("C:\\foo", nil, "C:", &.drive)
    assert_paths("C:/foo", nil, "C:", &.drive)
    assert_paths("C:foo", nil, "C:", &.drive)
    assert_paths("/foo", nil, nil, &.drive)
    assert_paths("//foo", nil, nil, &.drive)
    assert_paths("//some/share", nil, "//some/share", &.drive)
    assert_paths("//some/share/", nil, "//some/share", &.drive)
    assert_paths("//some/share/foo/", nil, "//some/share", &.drive)
    assert_paths("///not-a/share/", nil, nil, &.drive)
    assert_paths("/not-a//share/", nil, nil, &.drive)
    assert_paths("\\\\some\\share", nil, "\\\\some\\share", &.drive)
    assert_paths("\\\\some\\share\\", nil, "\\\\some\\share", &.drive)
    assert_paths("\\\\some\\share\\foo", nil, "\\\\some\\share", &.drive)
    assert_paths("\\\\\\not-a\\share", nil, nil, &.drive)
    assert_paths("\\\\not-a\\\\share", nil, nil, &.drive)
  end

  describe "#root" do
    assert_paths("C:\\foo", nil, "\\", &.root)
    assert_paths("C:/foo", nil, "/", &.root)
    assert_paths("C:foo", nil, nil, &.root)
    assert_paths("/foo", "/", &.root)
    assert_paths("//foo", "/", &.root)
    assert_paths("\\foo", nil, "\\", &.root)
    assert_paths("\\\\foo", nil, "\\", &.root)
    assert_paths("//some/share", "/", nil, &.root)
    assert_paths("\\\\some\\share", nil, &.root)
    assert_paths("//some/share/", "/", "/", &.root)
    assert_paths("\\\\some\\share\\", nil, "\\", &.root)
  end

  describe "#anchor" do
    assert_paths("C:\\foo", nil, "C:\\", &.anchor)
    assert_paths("C:/foo", nil, "C:/", &.anchor)
    assert_paths("C:foo", nil, "C:", &.anchor)
    assert_paths("/foo", "/", &.anchor)
    assert_paths("\\foo", nil, "\\", &.anchor)
    assert_paths("//some/share", "/", "//some/share", &.anchor)
    assert_paths("//some/share/", "/", "//some/share/", &.anchor)
    assert_paths("\\\\some\\share", nil, "\\\\some\\share", &.anchor)
    assert_paths("\\\\some\\share\\", nil, "\\\\some\\share\\", &.anchor)
  end

  describe "#normalize" do
    describe "path with forward slash" do
      describe "already clean" do
        it_normalizes_path("", ".", ".")
        it_normalizes_path("abc")
        it_normalizes_path("abc/def", windows: "abc\\def")
        it_normalizes_path("a/b/c", windows: "a\\b\\c")
        it_normalizes_path(".")
        it_normalizes_path("..")
        it_normalizes_path("../..", windows: "..\\..")
        it_normalizes_path("../../abc", windows: "..\\..\\abc")
        it_normalizes_path("/abc", windows: "\\abc")
        it_normalizes_path("/", windows: "\\")
      end

      describe "removes trailing slash" do
        it_normalizes_path("abc/", "abc", "abc")
        it_normalizes_path("abc/def/", "abc/def", "abc\\def")
        it_normalizes_path("a/b/c/", "a/b/c", "a\\b\\c")
        it_normalizes_path("./", ".", ".")
        it_normalizes_path("../", "..", "..")
        it_normalizes_path("../../", "../..", "..\\..")
        it_normalizes_path("/abc/", "/abc", "\\abc")
      end

      describe "removes double slash" do
        it_normalizes_path("abc//def//ghi", "abc/def/ghi", "abc\\def\\ghi")
        it_normalizes_path("//abc", "/abc", "\\abc")
        it_normalizes_path("///abc", "/abc", "\\abc")
        it_normalizes_path("//abc//", "/abc", "\\abc")
        it_normalizes_path("abc//", "abc", "abc")
      end

      describe "removes ." do
        it_normalizes_path("abc/./def", "abc/def", "abc\\def")
        it_normalizes_path("/./abc/def", "/abc/def", "\\abc\\def")
        it_normalizes_path("abc/.", "abc", "abc")
      end

      describe "removes .." do
        it_normalizes_path("abc/def/ghi/../jkl", "abc/def/jkl", "abc\\def\\jkl")
        it_normalizes_path("abc/def/../ghi/../jkl", "abc/jkl", "abc\\jkl")
        it_normalizes_path("abc/def/..", "abc", "abc")
        it_normalizes_path("abc/def/../..", ".", ".")
        it_normalizes_path("/abc/def/../..", "/", "\\")
        it_normalizes_path("abc/def/../../..", "..", "..")
        it_normalizes_path("/abc/def/../../..", "/", "\\")
        it_normalizes_path("abc/def/../../../ghi/jkl/../../../mno", "../../mno", "..\\..\\mno")
      end

      describe "combinations" do
        it_normalizes_path("abc/./../def", "def", "def")
        it_normalizes_path("abc//./../def", "def", "def")
        it_normalizes_path("abc/../../././../def", "../../def", "..\\..\\def")
      end
    end

    describe "paths with backslash" do
      describe "already clean" do
        it_normalizes_path("abc\\def")
        it_normalizes_path("a\\b\\c")
        it_normalizes_path("..\\..")
        it_normalizes_path("..\\..\\abc")
        it_normalizes_path("\\abc")
        it_normalizes_path("\\")
      end

      describe "removes trailing slash" do
        it_normalizes_path("abc\\", windows: "abc")
        it_normalizes_path("abc\\def\\", windows: "abc\\def")
        it_normalizes_path("a\\b\\c\\", windows: "a\\b\\c")
        it_normalizes_path(".\\", windows: ".")
        it_normalizes_path("..\\", windows: "..")
        it_normalizes_path("..\\..\\", windows: "..\\..")
        it_normalizes_path("\\abc\\", windows: "\\abc")
      end

      describe "removes double slash" do
        it_normalizes_path("abc\\\\def\\\\ghi", windows: "abc\\def\\ghi")
        it_normalizes_path("\\\\abc", windows: "\\abc")
        it_normalizes_path("\\\\\\abc", windows: "\\abc")
        it_normalizes_path("\\\\abc\\\\", windows: "\\abc")
        it_normalizes_path("abc\\\\", windows: "abc")
      end

      describe "removes ." do
        it_normalizes_path("abc\\.\\def", windows: "abc\\def")
        it_normalizes_path("\\.\\abc\\def", windows: "\\abc\\def")
        it_normalizes_path("abc\\.", windows: "abc")
      end

      describe "removes .." do
        it_normalizes_path("abc\\def\\ghi\\..\\jkl", windows: "abc\\def\\jkl")
        it_normalizes_path("abc\\def\\..\\ghi\\..\\jkl", windows: "abc\\jkl")
        it_normalizes_path("abc\\def\\..", windows: "abc")
        it_normalizes_path("abc\\def\\..\\..", windows: ".")
        it_normalizes_path("\\abc\\def\\..\\..", windows: "\\")
        it_normalizes_path("abc\\def\\..\\..\\..", windows: "..")
        it_normalizes_path("\\abc\\def\\..\\..\\..", windows: "\\")
        it_normalizes_path("abc\\def\\..\\..\\..\\ghi\\jkl\\..\\..\\..\\mno", windows: "..\\..\\mno")
      end

      describe "combinations" do
        it_normalizes_path("abc\\.\\..\\def", windows: "def")
        it_normalizes_path("abc\\\\.\\..\\def", windows: "def")
        it_normalizes_path("abc\\..\\..\\.\\.\\..\\def", windows: "..\\..\\def")
      end
    end

    describe "with drive" do
      it_normalizes_path("C:", "C:")
      it_normalizes_path("C:\\", "C:\\")
      it_normalizes_path("C:/", "C:", "C:\\")
      it_normalizes_path("C:foo", "C:foo")
      it_normalizes_path("C:\\foo", "C:\\foo")
      it_normalizes_path("C:/foo", "C:/foo", "C:\\foo")
    end
  end

  describe "#join" do
    it_joins_path("", "", "/", "\\")
    it_joins_path("/", "", "/")
    it_joins_path("", "/", "/")
    it_joins_path("foo", {"bar", ""}, "foo/bar/", "foo\\bar\\")
    it_joins_path("foo", {"bar", ""}, "foo/bar/", "foo\\bar\\")
    it_joins_path("///foo", "bar", "///foo/bar", "///foo\\bar")
    it_joins_path("///foo", "//bar", "///foo//bar")
    it_joins_path("/foo/", "/bar", "/foo/bar")
    it_joins_path("foo", "/", "foo/")
    it_joins_path("foo", {"bar", "baz"}, "foo/bar/baz", "foo\\bar\\baz")
    it_joins_path("foo", {"//bar//", "baz///"}, "foo//bar//baz///")
    it_joins_path("/foo/", {"/bar/", "/baz/"}, "/foo/bar/baz/")
    it_joins_path("", "a", "a")
    it_joins_path("/", "a", "/a")
    it_joins_path("", "/a", "/a")
    it_joins_path("foo", {"/", "bar"}, "foo/bar")
    it_joins_path("foo", {"/", "/", "bar"}, "foo/bar")
    it_joins_path("/", {"/foo", "/", "bar/", "/"}, "/foo/bar/")
    it_joins_path("c:/", "Program Files", "c:/Program Files")
    it_joins_path("c:", "Program Files", "c:/Program Files", "c:\\Program Files")

    it_joins_path("\\\\\\\\foo", "bar", "\\\\\\\\foo/bar", "\\\\\\\\foo\\bar")
    it_joins_path("\\\\\\foo", "\\\\bar", "\\\\\\foo/\\\\bar", "\\\\\\foo\\\\bar")
    it_joins_path("\\foo\\", "\\bar", "\\foo\\/\\bar", "\\foo\\bar")
    it_joins_path("foo", "\\", "foo/\\", "foo\\")
    it_joins_path("foo", {"\\\\bar\\\\", "baz\\\\\\"}, "foo/\\\\bar\\\\/baz\\\\\\", "foo\\\\bar\\\\baz\\\\\\")
    it_joins_path("\\foo\\", {"\\bar\\", "\\baz\\"}, "\\foo\\/\\bar\\/\\baz\\", "\\foo\\bar\\baz\\")
    it_joins_path("\\", "a", "\\/a", "\\a")
    it_joins_path("", "\\a", "\\a")
    it_joins_path("foo", {"\\", "bar"}, "foo/\\/bar", "foo\\bar")
    it_joins_path("foo", {"\\", "\\", "bar"}, "foo/\\/\\/bar", "foo\\bar")
    it_joins_path("\\", {"\\foo", "\\", "bar\\", "\\"}, "\\/\\foo/\\/bar\\/\\", "\\foo\\bar\\")
    it_joins_path("c:\\", "Program Files", "c:\\/Program Files", "c:\\Program Files")

    it_joins_path("foo", Path.windows("bar\\baz"), "foo/bar/baz", "foo\\bar\\baz")
    it_joins_path("foo", Path.posix("bar/baz"), "foo/bar/baz", "foo\\bar/baz")
  end

  describe "#expand" do
    describe "converts a pathname to an absolute pathname" do
      it_expands_path("", BASE_POSIX, BASE_WINDOWS)
      it_expands_path("a", {BASE_POSIX, "a"}, {BASE_WINDOWS, "a"})
      it_expands_path("a", {BASE_POSIX, "a"}, {BASE_WINDOWS, "a"})
    end

    describe "converts a pathname to an absolute pathname, Ruby-Talk:18512" do
      it_expands_path(".a", {BASE_POSIX, ".a"}, {BASE_WINDOWS, ".a"})
      it_expands_path("..a", {BASE_POSIX, "..a"}, {BASE_WINDOWS, "..a"})
      it_expands_path("a../b", {BASE_POSIX, "a../b"}, {BASE_WINDOWS, "a..\\b"})
    end

    describe "keeps trailing dots on absolute pathname" do
      it_expands_path("a.", {BASE_POSIX, "a."}, {BASE_WINDOWS, "a."})
      it_expands_path("a..", {BASE_POSIX, "a.."}, {BASE_WINDOWS, "a.."})
    end

    describe "converts a pathname to an absolute pathname, using a complete path" do
      it_expands_path("", "/tmp", "\\tmp", base: Path.posix("/tmp"))
      it_expands_path("", "C:/tmp", "C:\\tmp", base: Path.windows("C:\\tmp"))
      it_expands_path("a", "/tmp/a", "\\tmp\\a", base: Path.posix("/tmp"))
      it_expands_path("a", "C:/tmp/a", "C:\\tmp\\a", base: Path.windows("C:\\tmp"))
      it_expands_path("../a", "/tmp/a", "\\tmp\\a", base: Path.posix("/tmp/xxx"))
      it_expands_path("../a", "C:/tmp/a", "C:\\tmp\\a", base: Path.windows("C:\\tmp\\xxx"))
      it_expands_path("../a", "/tmp/a", "\\tmp\\a", base: Path.posix("/tmp/xxx"))
      it_expands_path("../a", "C:/tmp/a", "C:\\tmp\\a", base: Path.windows("C:\\tmp\\xxx"))
      it_expands_path(".", "/", "\\", base: Path.posix("/"))
      pending { it_expands_path(".", "C:/", "C:\\", base: Path.windows("C:\\")) }
    end

    describe "expands a path with multi-byte characters" do
      it_expands_path("Ångström", "#{BASE_POSIX}/Ångström", "#{BASE_WINDOWS}\\Ångström")
    end

    describe "expands /./dir to /dir" do
      it_expands_path("/./dir", "/dir", "\\dir", base: "/")
    end

    describe "replaces multiple / with a single /" do
      it_expands_path("//some/path", "/some/path", "\\\\some\\path#{BASE_WINDOWS}\\") # Windows path is UNC share
      it_expands_path("////some/path", "/some/path", "\\some\\path")
      it_expands_path("/some////path", "/some/path", "\\some\\path")
    end

    describe "expand path with" do
      it_expands_path("../../bin", "/bin", "\\bin", base: "/tmp/x")
      it_expands_path("../../bin", "/bin", "\\bin", base: "/tmp")
      it_expands_path("../../bin", "/bin", "\\bin", base: "/")
      it_expands_path("../bin", {Dir.current.gsub('\\', '/'), "tmp", "bin"}, {Path.windows(Dir.current).normalize.to_s, "tmp", "bin"}, base: "tmp/x", expand_base: true)
      it_expands_path("../bin", {Dir.current.gsub('\\', '/'), "bin"}, {Path.windows(Dir.current).normalize.to_s, "bin"}, base: "x/../tmp", expand_base: true)
    end

    describe "expand_path for commoms unix path give a full path" do
      it_expands_path("/tmp/", "/tmp/", "\\tmp\\")
      it_expands_path("/tmp/../../../tmp", "/tmp", "\\tmp")
      it_expands_path("", BASE_POSIX, BASE_WINDOWS)
      it_expands_path("./////", "#{BASE_POSIX}/", "#{BASE_WINDOWS}\\")
      it_expands_path(".", BASE_POSIX, BASE_WINDOWS)
      it_expands_path(BASE_POSIX, BASE_POSIX, BASE_POSIX.gsub('/', '\\'))
    end

    describe "with drive" do
      it_expands_path("foo", "D:/foo", "D:foo", base: "D:")
      it_expands_path("/foo", "/foo", "D:\\foo", base: "D:")
      it_expands_path("\\foo", "D:/\\foo", "D:\\foo", base: "D:")
      it_expands_path("foo", "D:\\/foo", "D:\\foo", base: Path.posix("D:\\"))
      it_expands_path("foo", "D:/foo", "D:\\foo", base: Path.windows("D:\\"))
      it_expands_path("foo", "D:/foo", "D:\\foo", base: "D:/")
      it_expands_path("/foo", "/foo", "D:\\foo", base: "D:\\")
      it_expands_path("\\foo", "D:\\/\\foo", "D:\\foo", base: Path.posix("D:\\"))
      it_expands_path("\\foo", "D:/\\foo", "D:\\foo", base: Path.windows("D:\\"))
      it_expands_path("/foo", "/foo", "D:\\foo", base: "D:/")
      it_expands_path("\\foo", "D:/\\foo", "D:\\foo", base: "D:/")

      it_expands_path("C:", "D:/C:", "C:", base: "D:")
      it_expands_path("C:", "D:/C:", "C:\\", base: "D:/")
      it_expands_path("C:", "D:\\/C:", "C:\\", base: Path.posix("D:\\"))
      it_expands_path("C:", "D:/C:", "C:\\", base: Path.windows("D:\\"))
      it_expands_path("C:/", "D:/C:/", "C:\\", base: "D:")
      it_expands_path("C:/", "D:/C:/", "C:\\", base: "D:/")
      it_expands_path("C:/", "D:\\/C:/", "C:\\", base: Path.posix("D:\\"))
      it_expands_path("C:/", "D:/C:/", "C:\\", base: Path.windows("D:\\"))
      it_expands_path("C:\\", "D:/C:\\", "C:\\", base: "D:")
      it_expands_path("C:\\", "D:/C:\\", "C:\\", base: "D:/")
      it_expands_path("C:\\", "D:\\/C:\\", "C:\\", base: Path.posix("D:\\"))
      it_expands_path("C:\\", "D:/C:\\", "C:\\", base: Path.windows("D:\\"))

      it_expands_path("C:foo", "D:/C:foo", "C:foo", base: "D:")
      it_expands_path("C:/foo", "D:/C:/foo", "C:\\foo", base: "D:")
      it_expands_path("C:\\foo", "D:/C:\\foo", "C:\\foo", base: "D:")
      it_expands_path("C:foo", "D:\\/C:foo", "C:\\foo", base: Path.posix("D:\\"))
      it_expands_path("C:foo", "D:/C:foo", "C:\\foo", base: Path.windows("D:\\"))
      it_expands_path("C:foo", "D:/C:foo", "C:\\foo", base: "D:/")
      it_expands_path("C:/foo", "D:\\/C:/foo", "C:\\foo", base: Path.posix("D:\\"))
      it_expands_path("C:/foo", "D:/C:/foo", "C:\\foo", base: Path.windows("D:\\"))
      it_expands_path("C:\\foo", "D:\\/C:\\foo", "C:\\foo", base: Path.posix("D:\\"))
      it_expands_path("C:\\foo", "D:/C:\\foo", "C:\\foo", base: Path.windows("D:\\"))
      it_expands_path("C:/foo", "D:/C:/foo", "C:\\foo", base: "D:/")
      it_expands_path("C:\\foo", "D:/C:\\foo", "C:\\foo", base: "D:/")
    end

    it "doesn't expand ~" do
      [Path["~"], Path["~", "foo"]].each do |path|
        path.expand(base: "", expand_base: false).should eq path
      end
    end

    describe "checks all possible types for expand(home:)" do
      home_posix2 = Path.posix(BASE_POSIX).join("foo").to_s
      home_windows2 = Path.windows(BASE_WINDOWS).join("foo").to_s

      home = Path[""].windows? ? home_windows2 : home_posix2
      it_expands_path("~/a", {BASE_POSIX, "~/a"}, {BASE_WINDOWS, "~\\a"}, home: false)
      it_expands_path("~/a", {home_posix2, "a"}, {home_windows2, "a"}, home: home)
      it_expands_path("~/a", {home_posix2, "a"}, {home_windows2, "a"}, home: Path[home])
    end

    describe "converts a pathname to an absolute pathname, using ~ (home) as base" do
      it_expands_path("~/", {HOME_POSIX, ""}, {HOME_WINDOWS, ""}, home: true)
      it_expands_path("~/..badfilename", {HOME_POSIX, "..badfilename"}, {HOME_WINDOWS, "..badfilename"}, home: true)
      it_expands_path("..", "/default", "\\default", home: true)
      it_expands_path("~/a", {HOME_POSIX, "a"}, {HOME_WINDOWS, "a"}, base: "~/b", home: true)
      it_expands_path("~", HOME_POSIX, HOME_WINDOWS, home: true)
      it_expands_path("~", HOME_POSIX, HOME_WINDOWS, base: "/tmp/gumby/ddd", home: true)
      it_expands_path("~/a", {HOME_POSIX, "a"}, {HOME_WINDOWS, "a"}, base: "/tmp/gumby/ddd", home: true)
    end

    describe "converts a pathname to an absolute pathname, using ~ (home) as base (trailing /)" do
      it_expands_path("~/", {HOME_POSIX, ""}, {HOME_WINDOWS, ""}, home: true)
      it_expands_path("~/..badfilename", {"#{HOME_POSIX}/", "..badfilename"}, {"#{HOME_WINDOWS}\\", "..badfilename"}, base: "", home: true)
      it_expands_path("~/..", "/home", "C:\\Users", home: true)
      it_expands_path("~/a", {HOME_POSIX, "a"}, {HOME_WINDOWS, "a"}, base: "~/b", home: true)
      it_expands_path("~", HOME_POSIX, HOME_WINDOWS, home: true)
      it_expands_path("~", HOME_POSIX, HOME_WINDOWS, base: "/tmp/gumby/ddd", home: true)
      it_expands_path("~/a", {HOME_POSIX, "a"}, {HOME_WINDOWS, "a"}, base: "/tmp/gumby/ddd", home: true)
    end

    describe "converts a pathname to an absolute pathname, using ~ (home) as base (HOME=/)" do
      it_expands_path("~/", "/", "\\", env_home: "/", home: true)
      it_expands_path("~/..badfilename", "/..badfilename", "\\..badfilename", env_home: "/", home: true)
      it_expands_path("..", "/default", "\\default", env_home: "/", home: true)
      it_expands_path("~/a", "/a", "\\a", base: "~/b", env_home: "/", home: true)
      it_expands_path("~", "/", "\\", env_home: "/", home: true)
      it_expands_path("~", "/", "\\", base: "/tmp/gumby/ddd", env_home: "/", home: true)
      it_expands_path("~/a", "/a", "\\a", base: "/tmp/gumby/ddd", env_home: "/", home: true)
    end

    describe "ignores name starting with ~" do
      it_expands_path("~foo.txt", "/current/~foo.txt", "\\current\\~foo.txt", base: "/current", env_home: "/")
    end
  end

  describe "#<=>" do
    it "case sensitivity" do
      Path.posix("foo").should_not eq Path.posix("FOO")
      Path.windows("foo").should eq Path.windows("FOO")
    end
  end

  describe "#ends_with_separator?" do
    assert_paths_raw("foo", false, &.ends_with_separator?)
    assert_paths_raw("foo/", true, &.ends_with_separator?)
    assert_paths_raw("foo\\", false, true, &.ends_with_separator?)
    assert_paths_raw("C:/", true, &.ends_with_separator?)
    assert_paths_raw("foo/bar", false, &.ends_with_separator?)
    assert_paths_raw("foo/.", false, &.ends_with_separator?)
  end

  describe "#to_windows" do
    assert_paths_raw("foo/bar", Path.windows("foo/bar"), &.to_windows)
    assert_paths_raw("C:\\foo\\bar", Path.windows("C:\\foo\\bar"), &.to_windows)
  end

  describe "to_posix" do
    assert_paths_raw("foo/bar", Path.posix("foo/bar"), &.to_posix)
    assert_paths_raw("C:\\foo\\bar", Path.posix("C:\\foo\\bar"), Path.posix("C:/foo/bar"), &.to_posix)
  end
end
