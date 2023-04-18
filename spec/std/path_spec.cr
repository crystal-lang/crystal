require "spec"
require "./spec_helper"
require "../support/env"

private HOME_ENV_KEY = {% if flag?(:win32) %} "USERPROFILE" {% else %} "HOME" {% end %}
private BASE_POSIX   = "/default/base"
private BASE_WINDOWS = "\\default\\base"
private HOME_WINDOWS = "C:\\Users\\Crystal"
private HOME_POSIX   = "/home/crystal"

private def it_normalizes_path(path, posix = path, windows = path, file = __FILE__, line = __LINE__)
  assert_paths(path, posix, windows, "normalizes", file, line, &.normalize)
end

private def it_expands_path(path, posix, windows = posix, *, base = nil, env_home = nil, expand_base = false, home = false, file = __FILE__, line = __LINE__)
  assert_paths(path, posix, windows, %((base: "#{base}")), file, line) do |path|
    with_env({HOME_ENV_KEY => env_home}) do
      base_arg = base || (path.windows? ? BASE_WINDOWS : BASE_POSIX)
      base_arg = path.windows? ? Path.windows(base_arg) : Path.posix(base_arg) unless base_arg.is_a?(Path)
      if home == true && env_home.nil?
        myhome = path.windows? ? Path.windows(HOME_WINDOWS) : Path.posix(HOME_POSIX)
      else
        myhome = home
      end
      path.expand(base_arg, expand_base: !!expand_base, home: myhome)
    end
  end
end

private def it_joins_path(path, parts, posix, windows = posix, file = __FILE__, line = __LINE__)
  assert_paths(path, posix, windows, %(resolving "#{parts}"), file, line, &.join(parts))
  unless parts.is_a?(Enumerable)
    # FIXME: Omitting the type cast results in Error: can't infer block return type, try to cast the block body with `as`.
    assert_paths(path, posix, windows, %(resolving ["#{parts}"] ), file, line, &.join([parts]).as(Path))
    assert_paths(path, posix, windows, %(resolving ["#{parts}"].each), file, line, &.join([parts].each).as(Path))
  end
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
    block.call(Path.posix(path)).should eq(posix), file: file, line: line
  end
  it %(#{label} "#{path}" (windows)), file, line do
    block.call(Path.windows(path)).should eq(windows), file: file, line: line
  end
end

private def it_relativizes(base, target, posix, windows = posix, file = __FILE__, line = __LINE__)
  assert_paths target, posix, windows, %(on "#{base}":), file, line do |path|
    path.relative_to?(base)
  end
end

private def it_iterates_parts(path, posix, windows = posix, file = __FILE__, line = __LINE__)
  assert_paths_raw path, posix, windows, label: "block", file: file, line: line do |path|
    array = [] of String
    path.each_part do |part|
      array << part
    end
    array
  end
  assert_paths_raw path, posix, windows, label: "iterator", file: file, line: line do |path|
    array = [] of String
    path.each_part.each do |part|
      array << part
    end
    array
  end
  assert_paths_raw path, posix, windows, label: "#parts", file: file, line: line do |path|
    path.parts
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

    it "joins components" do
      Path.new("foo", "bar").should eq Path.new("foo").join("bar")
      Path.new(Path.new("foo"), "bar").should eq Path.new("foo", "bar")
      Path.new(Path.posix("foo"), "bar").should eq Path.new("foo", "bar")
      Path.new(Path.windows("foo"), "bar").should eq Path.new("foo", "bar")

      # implicit conversion:
      Path.windows("foo", Path.posix("bar\\baz")).should eq Path.windows("foo").join(Path.posix("bar\\baz").to_windows)
    end
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

    it "joins components" do
      Path.posix("foo", "bar").should eq Path.posix("foo").join("bar")
      Path.posix(Path.new("foo"), "bar").should eq Path.posix("foo", "bar")
      Path.posix(Path.posix("foo"), "bar").should eq Path.posix("foo", "bar")
      Path.posix(Path.windows("foo"), "bar").should eq Path.posix("foo", "bar")
    end
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

    it "joins components" do
      Path.windows("foo", "bar").should eq Path.windows("foo").join("bar")
      Path.windows(Path.new("foo"), "bar").should eq Path.windows("foo", "bar")
      Path.windows(Path.posix("foo"), "bar").should eq Path.windows("foo", "bar")
      Path.windows(Path.windows("foo"), "bar").should eq Path.windows("foo", "bar")
    end
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

  describe "#each_part" do
    it_iterates_parts("/Users/foo/bar.cr", ["/", "Users", "foo", "bar.cr"])
    it_iterates_parts("Users/foo/bar.cr", ["Users", "foo", "bar.cr"])
    it_iterates_parts("foo/bar/", ["foo", "bar"])
    it_iterates_parts("foo/bar/.", ["foo", "bar", "."])
    it_iterates_parts("foo", ["foo"])
    it_iterates_parts("foo/", ["foo"])
    it_iterates_parts("/", ["/"])
    it_iterates_parts("////", ["////"])
    it_iterates_parts("/.", ["/", "."])
    it_iterates_parts("/foo", ["/", "foo"])
    it_iterates_parts("", [] of String)
    it_iterates_parts("./foo", [".", "foo"])
    it_iterates_parts(".", ["."])
    it_iterates_parts("\\Users\\foo\\bar.cr", ["\\Users\\foo\\bar.cr"], ["\\", "Users", "foo", "bar.cr"])
    it_iterates_parts("\\Users/foo\\bar.cr", ["\\Users", "foo\\bar.cr"], ["\\", "Users", "foo", "bar.cr"])
    it_iterates_parts("C:\\Users\\foo\\bar.cr", ["C:\\Users\\foo\\bar.cr"], ["C:\\", "Users", "foo", "bar.cr"])
    it_iterates_parts("\\\\some\\share\\", ["\\\\some\\share\\"], ["\\\\some\\share\\"])
    it_iterates_parts("\\\\some\\share", ["\\\\some\\share"])
    it_iterates_parts("\\\\some\\share\\bar.cr", ["\\\\some\\share\\bar.cr"], ["\\\\some\\share\\", "bar.cr"])
    it_iterates_parts("//some/share", ["//", "some", "share"], ["//some/share"])
    it_iterates_parts("//some/share/", ["//", "some", "share"], ["//some/share/"])
    it_iterates_parts("//some/share/bar.cr", ["//", "some", "share", "bar.cr"], ["//some/share/", "bar.cr"])
    it_iterates_parts("foo\\bar\\", ["foo\\bar\\"], ["foo", "bar"])
    it_iterates_parts("foo\\", ["foo\\"], ["foo"])
    it_iterates_parts("\\", ["\\"], ["\\"])
    it_iterates_parts(".\\foo", [".\\foo"], [".", "foo"])
    it_iterates_parts("foo/../bar/", ["foo", "..", "bar"])
    it_iterates_parts("foo/../bar/.", ["foo", "..", "bar", "."])
    it_iterates_parts("foo/bar/..", ["foo", "bar", ".."])
    it_iterates_parts("foo/bar/../.", ["foo", "bar", "..", "."])
    it_iterates_parts("foo/./bar/", ["foo", ".", "bar"])
    it_iterates_parts("foo/./bar/.", ["foo", ".", "bar", "."])
    it_iterates_parts("foo/bar/.", ["foo", "bar", "."])
    it_iterates_parts("foo/bar/./.", ["foo", "bar", ".", "."])
    it_iterates_parts("m/.gitignore", ["m", ".gitignore"])
    it_iterates_parts("m", ["m"])
    it_iterates_parts("m/", ["m"])
    it_iterates_parts("m//", ["m"])
    it_iterates_parts("m\\", ["m\\"], ["m"])
    it_iterates_parts("m//a/b", ["m", "a", "b"])
    it_iterates_parts("m\\a/b", ["m\\a", "b"], ["m", "a", "b"])
    it_iterates_parts("/m", ["/", "m"])
    it_iterates_parts("/m/", ["/", "m"])
    it_iterates_parts("C:", ["C:"])
    it_iterates_parts("C:/", ["C:"], ["C:/"])
    it_iterates_parts("C:\\", ["C:\\"])
    it_iterates_parts("C:folder", ["C:folder"], ["C:", "folder"])
    it_iterates_parts("C:\\folder", ["C:\\folder"], ["C:\\", "folder"])
    it_iterates_parts("C:\\\\folder", ["C:\\\\folder"], ["C:\\\\", "folder"])
    it_iterates_parts("C:\\.", ["C:\\."], ["C:\\", "."])
  end

  describe "#extension" do
    assert_paths_raw("/foo/bar/baz.cr", ".cr", &.extension)
    assert_paths_raw("/foo/bar/baz.cr.cz", ".cz", &.extension)
    assert_paths_raw("/foo/bar/.profile", "", &.extension)
    assert_paths_raw("/foo/bar/.profile.sh", ".sh", &.extension)
    assert_paths_raw("/foo/bar/foo.", "", &.extension)
    assert_paths_raw("test", "", &.extension)
    assert_paths_raw("test.ext/foo", "", &.extension)
    assert_paths_raw("test.ext/foo/", "", &.extension)
    assert_paths_raw("test.ext/", ".ext", &.extension)
    assert_paths_raw("test/.", "", &.extension)
    assert_paths_raw("test\\.", "", &.extension)
    assert_paths_raw("test.ext\\", ".ext\\", ".ext", &.extension)
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

    assert_paths("\\\\some$\\share\\", nil, "\\\\some$\\share", &.drive)
    assert_paths("\\\\%10%20\\share\\", nil, "\\\\%10%20\\share", &.drive)
    assert_paths("\\\\_.-~!$;=&'()*+,aB1\\ !-.@^_`{}~#$%&'()aB1\\", nil, "\\\\_.-~!$;=&'()*+,aB1\\ !-.@^_`{}~#$%&'()aB1", &.drive)
    assert_paths("\\\\127.0.0.1\\share\\", nil, "\\\\127.0.0.1\\share", &.drive)
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
    it_joins_path("foo", Path.posix("bar\\baz"), "foo/bar\\baz", "foo\\bar\uF05Cbaz")
    it_joins_path("foo", Path.posix("bar/baz"), "foo/bar/baz", "foo\\bar/baz")
  end

  describe "#expand" do
    describe "converts a pathname to an absolute pathname" do
      it_expands_path("", BASE_POSIX, BASE_WINDOWS)
      it_expands_path("a", {BASE_POSIX, "a"}, {BASE_WINDOWS, "a"})
      it_expands_path("a", {BASE_POSIX, "a"}, {BASE_WINDOWS, "a"}, base: nil)
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

    describe "expand path with .." do
      it_expands_path("../../bin", "/bin", "\\bin", base: "/tmp/x")
      it_expands_path("../../bin", "/bin", "\\bin", base: "/tmp")
      it_expands_path("../../bin", "/bin", "\\bin", base: "/")
      it_expands_path("../bin", {Dir.current.gsub('\\', '/'), "tmp", "bin"}, {Path.windows(Dir.current).normalize.to_s, "tmp", "bin"}, base: "tmp/x", expand_base: true)
      it_expands_path("../bin", {Dir.current.gsub('\\', '/'), "bin"}, {Path.windows(Dir.current).normalize.to_s, "bin"}, base: "x/../tmp", expand_base: true)
    end

    describe "expand_path for common unix path gives a full path" do
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
      it_expands_path("foo", "D:\\/foo", "D\uF03A\uF05C\\foo", base: Path.posix("D:\\"))
      it_expands_path("foo", "D:/foo", "D:\\foo", base: Path.windows("D:\\"))
      it_expands_path("foo", "D:/foo", "D:\\foo", base: "D:/")
      it_expands_path("/foo", "/foo", "D:\\foo", base: "D:\\")
      it_expands_path("\\foo", "D:\\/\\foo", "\\foo", base: Path.posix("D:\\"))
      it_expands_path("\\foo", "D:/\\foo", "D:\\foo", base: Path.windows("D:\\"))
      it_expands_path("/foo", "/foo", "D:\\foo", base: "D:/")
      it_expands_path("\\foo", "D:/\\foo", "D:\\foo", base: "D:/")

      it_expands_path("C:", "D:/C:", "C:", base: "D:")
      it_expands_path("C:", "D:/C:", "C:\\", base: "D:/")
      it_expands_path("C:", "D:\\/C:", "C:D\uF03A\uF05C\\", base: Path.posix("D:\\"))
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
      it_expands_path("C:foo", "D:\\/C:foo", "C:D\uF03A\uF05C\\foo", base: Path.posix("D:\\"))
      it_expands_path("C:foo", "D:/C:foo", "C:\\foo", base: Path.windows("D:\\"))
      it_expands_path("C:foo", "D:/C:foo", "C:\\foo", base: "D:/")
      it_expands_path("C:/foo", "D:\\/C:/foo", "C:\\foo", base: Path.posix("D:\\"))
      it_expands_path("C:/foo", "D:/C:/foo", "C:\\foo", base: Path.windows("D:\\"))
      it_expands_path("C:\\foo", "D:\\/C:\\foo", "C:\\foo", base: Path.posix("D:\\"))
      it_expands_path("C:\\foo", "D:/C:\\foo", "C:\\foo", base: Path.windows("D:\\"))
      it_expands_path("C:/foo", "D:/C:/foo", "C:\\foo", base: "D:/")
      it_expands_path("C:\\foo", "D:/C:\\foo", "C:\\foo", base: "D:/")
    end

    describe "UNC path" do
      it_expands_path("baz", "/foo/bar/baz", "\\\\foo\\bar\\baz", base: Path.windows("\\\\foo\\bar\\"))
      it_expands_path("baz", "/foo$/bar/baz", "\\\\foo$\\bar\\baz", base: Path.windows("\\\\foo$\\bar\\"))
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

    describe %q(supports ~\ for Windows paths only) do
      it_expands_path("~\\a", {BASE_POSIX, "~\\a"}, {HOME_WINDOWS, "a"}, home: true)
    end
  end

  describe "#<=>" do
    it "case sensitivity" do
      (Path.posix("foo") <=> Path.posix("FOO")).should eq 1
      (Path.windows("foo") <=> Path.windows("FOO")).should eq 0
      (Path.windows("foo") <=> Path.posix("FOO")).should eq 1
      (Path.posix("foo") <=> Path.windows("FOO")).should eq -1
    end
  end

  describe "#==" do
    it "simple" do
      Path.posix("foo").should eq Path.posix("foo")
      Path.windows("foo").should eq Path.windows("foo")
      Path.windows("foo").should_not eq Path.posix("foo")
      Path.posix("foo").should_not eq Path.windows("foo")
    end

    it "case sensitivity" do
      Path.posix("foo").should_not eq Path.posix("FOO")
      Path.windows("foo").should eq Path.windows("FOO")
      Path.windows("foo").should_not eq Path.posix("FOO")
      Path.posix("foo").should_not eq Path.windows("FOO")
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
    assert_paths_raw("C:\\foo\\bar", Path.windows("C\uF03A\uF05Cfoo\uF05Cbar"), Path.windows("C:\\foo\\bar"), label: "default: mappings=true", &.to_windows)

    assert_paths_raw("foo/bar", Path.windows("foo/bar"), &.to_windows(mappings: true))
    assert_paths_raw("C:\\foo\\bar", Path.windows("C\uF03A\uF05Cfoo\uF05Cbar"), Path.windows("C:\\foo\\bar"), &.to_windows(mappings: true))
    assert_paths_raw(%("*/:<>?\\| ), Path.windows("\uF022\uF02A/\uF03A\uF03C\uF03E\uF03F\uF05C\uF07C\uF020"), Path.windows(%("*/:<>?\\| )), &.to_windows(mappings: true))

    assert_paths_raw("foo/bar", Path.windows("foo/bar"), &.to_windows(mappings: false))
    assert_paths_raw("C:\\foo\\bar", Path.windows("C:\\foo\\bar"), &.to_windows(mappings: false))
    assert_paths_raw(%("*/:<>?\\| ), Path.windows(%("*/:<>?\\| )), &.to_windows(mappings: false))
  end

  describe "#to_posix" do
    assert_paths_raw("C\uF03A\uF05Cfoo\uF05Cbar", Path.posix("C\uF03A\uF05Cfoo\uF05Cbar"), Path.posix("C:\\foo\\bar"), label: "default: mappings=true", &.to_posix)

    assert_paths_raw("foo/bar", Path.posix("foo/bar"), &.to_posix(mappings: true))
    assert_paths_raw("C:\\foo\\bar", Path.posix("C:\\foo\\bar"), Path.posix("C:/foo/bar"), &.to_posix(mappings: true))
    assert_paths_raw("C\uF03A\uF05Cfoo\uF05Cbar", Path.posix("C\uF03A\uF05Cfoo\uF05Cbar"), Path.posix("C:\\foo\\bar"), &.to_posix(mappings: true))
    assert_paths_raw("\uF022\uF02A/\uF03A\uF03C\uF03E\uF03F\uF05C\uF07C\uF020", Path.posix("\uF022\uF02A/\uF03A\uF03C\uF03E\uF03F\uF05C\uF07C\uF020"), Path.posix(%("*/:<>?\\| )), &.to_posix(mappings: true))

    assert_paths_raw("foo/bar", Path.posix("foo/bar"), &.to_posix(mappings: false))
    assert_paths_raw("C:\\foo\\bar", Path.posix("C:\\foo\\bar"), Path.posix("C:/foo/bar"), &.to_posix(mappings: false))
    assert_paths_raw("C\uF03A\uF05Cfoo\uF05Cbar", Path.posix("C\uF03A\uF05Cfoo\uF05Cbar"), &.to_posix(mappings: false))
    assert_paths_raw("\uF022\uF02A/\uF03A\uF03C\uF03E\uF03F\uF05C\uF07C\uF020", Path.posix("\uF022\uF02A/\uF03A\uF03C\uF03E\uF03F\uF05C\uF07C\uF020"), &.to_posix(mappings: false))
  end

  describe "#relative_to?" do
    it_relativizes("a/b", "a/b/c", "c")
    it_relativizes("a/b", "a/b", ".")
    it_relativizes("a/b/.", "a/b", ".")
    it_relativizes("a/b", "a/b/.", ".")
    it_relativizes("./a/b", "a/b", ".")
    it_relativizes("a/b", "./a/b", ".")
    it_relativizes("ab/cd", "ab/cde", "../cde", "..\\cde")
    it_relativizes("ab/cd", "ab/c", "../c", "..\\c")
    it_relativizes("a/b", "a/b/c/d", "c/d", "c\\d")
    it_relativizes("a/b", "a/b/../c", "../c", "..\\c")
    it_relativizes("a/b/../c", "a/b", "../b", "..\\b")
    it_relativizes("a/b/c", "a/c/d", "../../c/d", "..\\..\\c\\d")
    it_relativizes("a/b", "c/d", "../../c/d", "..\\..\\c\\d")
    it_relativizes("a/b/c/d", "a/b", "../..", "..\\..")
    it_relativizes("a/b/c/d", "a/b/", "../..", "..\\..")
    it_relativizes("a/b/c/d/", "a/b", "../..", "..\\..")
    it_relativizes("a/b/c/d/", "a/b/", "../..", "..\\..")
    it_relativizes("../../a/b", "../../a/b/c/d", "c/d", "c\\d")
    it_relativizes("/a/b", "/a/b", ".")
    it_relativizes("/a/b/.", "/a/b", ".")
    it_relativizes("/a/b", "/a/b/.", ".")
    it_relativizes("/ab/cd", "/ab/cde", "../cde", "..\\cde")
    it_relativizes("/ab/cd", "/ab/c", "../c", "..\\c")
    it_relativizes("/a/b", "/a/b/c/d", "c/d", "c\\d")
    it_relativizes("/a/b", "/a/b/../c", "../c", "..\\c")
    it_relativizes("/a/b/../c", "/a/b", "../b", "..\\b")
    it_relativizes("/a/b/c", "/a/c/d", "../../c/d", "..\\..\\c\\d")
    it_relativizes("/a/b", "/c/d", "../../c/d", "..\\..\\c\\d")
    it_relativizes("/a/b/c/d", "/a/b", "../..", "..\\..")
    it_relativizes("/a/b/c/d", "/a/b/", "../..", "..\\..")
    it_relativizes("/a/b/c/d/", "/a/b", "../..", "..\\..")
    it_relativizes("/a/b/c/d/", "/a/b/", "../..", "..\\..")
    it_relativizes("/../../a/b", "/../../a/b/c/d", "c/d", "c\\d")
    it_relativizes("/", "/a/c", "a/c", "a\\c")
    it_relativizes("/", "/", ".")
    it_relativizes(".", "a/b", "a/b", "a\\b")
    it_relativizes(".", "..", "..")
    # can't do purely lexically
    it_relativizes("..", ".", nil)
    it_relativizes("..", "a", nil)
    it_relativizes("../..", "..", nil)
    it_relativizes("a", "/a", nil)

    describe "special windows paths" do
      it_relativizes("/a", "a", nil)
      it_relativizes("C:a\\b\\c", "C:a/b/d", "../C:a/b/d", "..\\d")
      it_relativizes("C:a\\b\\c", "c:a/b/d", "../c:a/b/d", "..\\d")
      it_relativizes("C:\\", "D:\\", "../D:\\", nil)
      it_relativizes("C:", "D:", "../D:", nil)
      it_relativizes("C:\\Projects", "c:\\projects\\src", "../c:\\projects\\src", "src")
      it_relativizes("C:\\Projects", "c:\\projects", "../c:\\projects", ".")
      it_relativizes("C:\\Projects\\a\\..", "c:\\projects", "../c:\\projects", ".")
    end
  end

  describe "#relative_to" do
    it "relativizable paths" do
      Path.posix("a/b/c").relative_to("a/b").should eq Path.posix("c")
      Path.windows("a\\b\\c").relative_to("a\\b").should eq Path.windows("c")
    end

    it "mixed input paths" do
      Path.posix("a/b/c").relative_to(Path.windows("a\\b")).should eq Path.posix("c")
      Path.windows("a\\b\\c").relative_to(Path.posix("a/b")).should eq Path.windows("c")
    end

    it "paths that can't be relativized" do
      path = Path.posix(".")
      path.relative_to(Path.posix("/cwd")).should eq path
      path = Path.windows(".")
      path.relative_to(Path.windows("/cwd")).should eq path
      path = Path.windows(".")
      path.relative_to(Path.windows("C:/cwd")).should eq path
      path = Path.windows(".")
      path.relative_to(Path.windows("C:cwd")).should eq path
    end
  end

  describe "#stem" do
    assert_paths_raw("foo.txt", "foo", &.stem)
    assert_paths_raw("foo.txt.txt", "foo.txt", &.stem)
    assert_paths_raw(".txt", ".txt", &.stem)
    assert_paths_raw(".txt.txt", ".txt", &.stem)
    assert_paths_raw("foo.", "foo.", &.stem)
    assert_paths_raw("foo.txt.", "foo.txt.", &.stem)
    assert_paths_raw("foo..txt", "foo.", &.stem)

    assert_paths_raw("bar/foo.txt", "foo", &.stem)
    assert_paths_raw("bar/foo.txt.txt", "foo.txt", &.stem)
    assert_paths_raw("bar/.txt", ".txt", &.stem)
    assert_paths_raw("bar/.txt.txt", ".txt", &.stem)
    assert_paths_raw("bar/foo.", "foo.", &.stem)
    assert_paths_raw("bar/foo.txt.", "foo.txt.", &.stem)
    assert_paths_raw("bar/foo..txt", "foo.", &.stem)

    assert_paths_raw("bar\\foo.txt", "bar\\foo", "foo", &.stem)
    assert_paths_raw("bar\\foo.txt.txt", "bar\\foo.txt", "foo.txt", &.stem)
    assert_paths_raw("bar\\.txt", "bar\\", ".txt", &.stem)
    assert_paths_raw("bar\\.txt.txt", "bar\\.txt", ".txt", &.stem)
    assert_paths_raw("bar\\foo.", "bar\\foo.", "foo.", &.stem)
    assert_paths_raw("bar\\foo.txt.", "bar\\foo.txt.", "foo.txt.", &.stem)
    assert_paths_raw("bar\\foo..txt", "bar\\foo.", "foo.", &.stem)

    assert_paths_raw("foo.txt/", "foo", &.stem)
    assert_paths_raw("foo.txt.txt/", "foo.txt", &.stem)
    assert_paths_raw(".txt/", ".txt", &.stem)
    assert_paths_raw(".txt.txt/", ".txt", &.stem)
    assert_paths_raw("foo./", "foo.", &.stem)
    assert_paths_raw("foo.txt./", "foo.txt.", &.stem)
    assert_paths_raw("foo..txt/", "foo.", &.stem)
  end

  describe ".home" do
    it "uses home from environment variable if set" do
      with_env({HOME_ENV_KEY => "foo/bar"}) do
        Path.home.should eq(Path.new("foo/bar"))
      end
    end

    # TODO: check that the cases below return the home of the current user (via #7829)
    it "doesn't return empty string if environment variable is empty" do
      with_env({HOME_ENV_KEY => ""}) do
        Path.home.should_not eq(Path.new(""))
      end
    end

    it "doesn't raise if environment variable is missing" do
      with_env({HOME_ENV_KEY => nil}) do
        Path.home.should be_a(Path)
      end
    end
  end
end
