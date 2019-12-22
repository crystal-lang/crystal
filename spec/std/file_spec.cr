require "./spec_helper"
require "../support/errno"

private def base
  Dir.current
end

private def tmpdir
  "/tmp"
end

private def rootdir
  "/"
end

private def home
  home = ENV["HOME"]
  return home if home == "/"

  home.chomp('/')
end

private def it_raises_on_null_byte(operation, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
  it "errors on #{operation}", file, line, end_line do
    expect_raises(ArgumentError, "String contains null byte") do
      block.call
    end
  end
end

private def normalize_permissions(permissions, *, directory)
  {% if flag?(:win32) %}
    normalized_permissions = 0o444
    normalized_permissions |= 0o222 if permissions.bits_set?(0o200)
    normalized_permissions |= 0o111 if directory
    File::Permissions.new(normalized_permissions)
  {% else %}
    File::Permissions.new(permissions)
  {% end %}
end

describe "File" do
  it "gets path" do
    path = datapath("test_file.txt")
    File.open(path) do |file|
      file.path.should eq(path)
    end
  end

  it "reads entire file" do
    str = File.read datapath("test_file.txt")
    str.should eq("Hello World\n" * 20)
  end

  {% if flag?(:linux) %}
    it "reads entire file from proc virtual filesystem" do
      str1 = File.open "/proc/self/cmdline", &.gets_to_end
      str2 = File.read "/proc/self/cmdline"
      str2.empty?.should be_false
      str2.should eq(str1)
    end
  {% end %}

  it "reads lines from file" do
    lines = File.read_lines datapath("test_file.txt")
    lines.size.should eq(20)
    lines.first.should eq("Hello World")
  end

  it "reads lines from file with chomp = false" do
    lines = File.read_lines datapath("test_file.txt"), chomp: false
    lines.size.should eq(20)
    lines.first.should eq("Hello World\n")
  end

  it "reads lines from file with each" do
    idx = 0
    File.each_line(datapath("test_file.txt")) do |line|
      if idx == 0
        line.should eq("Hello World")
      end
      idx += 1
    end
    idx.should eq(20)
  end

  it "reads lines from file with each, chomp = false" do
    idx = 0
    File.each_line(datapath("test_file.txt"), chomp: false) do |line|
      if idx == 0
        line.should eq("Hello World\n")
      end
      idx += 1
    end
    idx.should eq(20)
  end

  describe "empty?" do
    it "gives true when file is empty" do
      File.empty?(datapath("blank_test_file.txt")).should be_true
    end

    it "gives false when file is not empty" do
      File.empty?(datapath("test_file.txt")).should be_false
    end

    it "raises an error when the file does not exist" do
      filename = datapath("non_existing_file.txt")
      expect_raises_errno(Errno::ENOENT, "Error determining size of '#{filename}'") do
        File.empty?(filename)
      end
    end

    # TODO: do we even want this?
    pending_win32 "raises an error when a component of the path is a file" do
      expect_raises_errno(Errno::ENOTDIR, "Error determining size of '#{datapath("test_file.txt", "")}'") do
        File.empty?(datapath("test_file.txt", ""))
      end
    end
  end

  describe "exists?" do
    it "gives true" do
      File.exists?(datapath("test_file.txt")).should be_true
    end

    it "gives false" do
      File.exists?(datapath("non_existing_file.txt")).should be_false
    end

    it "gives false when a component of the path is a file" do
      File.exists?(datapath("dir", "test_file.txt", "")).should be_false
    end
  end

  # TODO: implement this for win32
  describe "executable?" do
    pending_win32 "gives false" do
      File.executable?(datapath("test_file.txt")).should be_false
    end

    pending_win32 "gives false when the file doesn't exist" do
      File.executable?(datapath("non_existing_file.txt")).should be_false
    end

    pending_win32 "gives false when a component of the path is a file" do
      File.executable?(datapath("dir", "test_file.txt", "")).should be_false
    end
  end

  describe "readable?" do
    it "gives true" do
      File.readable?(datapath("test_file.txt")).should be_true
    end

    it "gives false when the file doesn't exist" do
      File.readable?(datapath("non_existing_file.txt")).should be_false
    end

    it "gives false when a component of the path is a file" do
      File.readable?(datapath("dir", "test_file.txt", "")).should be_false
    end
  end

  describe "writable?" do
    it "gives true" do
      File.writable?(datapath("test_file.txt")).should be_true
    end

    it "gives false when the file doesn't exist" do
      File.writable?(datapath("non_existing_file.txt")).should be_false
    end

    it "gives false when a component of the path is a file" do
      File.writable?(datapath("dir", "test_file.txt", "")).should be_false
    end
  end

  describe "file?" do
    it "gives true" do
      File.file?(datapath("test_file.txt")).should be_true
    end

    it "gives false with dir" do
      File.file?(datapath("dir")).should be_false
    end

    it "gives false when the file doesn't exist" do
      File.file?(datapath("non_existing_file.txt")).should be_false
    end

    it "gives false when a component of the path is a file" do
      File.file?(datapath("dir", "test_file.txt", "")).should be_false
    end
  end

  describe "directory?" do
    it "gives true" do
      File.directory?(datapath).should be_true
    end

    it "gives false" do
      File.directory?(datapath("test_file.txt")).should be_false
    end

    it "gives false when the directory doesn't exist" do
      File.directory?(datapath("non_existing")).should be_false
    end

    it "gives false when a component of the path is a file" do
      File.directory?(datapath("dir", "test_file.txt", "")).should be_false
    end
  end

  describe "link" do
    it "creates a hard link" do
      with_tempfile("hard_link_source.txt", "hard_link_target.txt") do |in_path, out_path|
        File.write(in_path, "")
        File.link(in_path, out_path)
        File.exists?(out_path).should be_true
        File.symlink?(out_path).should be_false
        File.same?(in_path, out_path).should be_true
      end
    end
  end

  describe "same?" do
    it "compares following symlinks only if requested" do
      file = datapath("test_file.txt")
      other = datapath("test_file.ini")

      with_tempfile("test_file_symlink.txt") do |symlink|
        File.symlink(File.real_path(file), symlink)

        File.same?(file, symlink).should be_false
        File.same?(file, symlink, follow_symlinks: true).should be_true
        File.same?(file, symlink, follow_symlinks: false).should be_false
        File.same?(file, other).should be_false
      end
    end
  end

  describe "symlink" do
    it "creates a symbolic link" do
      in_path = datapath("test_file.txt")
      with_tempfile("test_file_link.txt") do |out_path|
        File.symlink(File.real_path(in_path), out_path)
        File.symlink?(out_path).should be_true
        File.same?(in_path, out_path, follow_symlinks: true).should be_true
      end
    end
  end

  describe "symlink?" do
    it "gives true" do
      File.symlink?(datapath("symlink.txt")).should be_true
    end

    it "gives false" do
      File.symlink?(datapath("test_file.txt")).should be_false
      File.symlink?(datapath("unknown_file.txt")).should be_false
    end

    it "gives false when the symlink doesn't exist" do
      File.symlink?(datapath("non_existing_file.txt")).should be_false
    end

    it "gives false when a component of the path is a file" do
      File.symlink?(datapath("dir", "test_file.txt", "")).should be_false
    end
  end

  describe ".readlink" do
    it "reads link" do
      File.readlink(datapath("symlink.txt")).should eq "test_file.txt"
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
    File.basename("/").should eq("/")
  end

  it "gets basename removing suffix" do
    File.basename("/foo/bar/baz.cr", ".cr").should eq("baz")
  end

  it "gets extname" do
    File.extname("/foo/bar/a.cr").should eq(".cr")
    File.extname("/foo/bar/baz.cr").should eq(".cr")
    File.extname("/foo/bar/baz.cr.cz").should eq(".cz")
    File.extname("/foo/bar/.profile").should eq("")
    File.extname("/foo/bar/.profile.sh").should eq(".sh")
    File.extname("/foo/bar/foo.").should eq("")
    File.extname("/foo.bar/baz").should eq("")
    File.extname("a.cr").should eq(".cr")
    File.extname("test.cr").should eq(".cr")
    File.extname("test.cr.cz").should eq(".cz")
    File.extname(".test").should eq("")
    File.extname(".test.cr").should eq(".cr")
    File.extname(".test.cr.cz").should eq(".cz")
    File.extname("test").should eq("")
    File.extname("test.").should eq("")
    File.extname("").should eq("")
  end

  it "constructs a path from parts" do
    File.join(["///foo", "bar"]).should eq("///foo/bar")
    File.join(["///foo", "//bar"]).should eq("///foo//bar")
    File.join(["/foo/", "/bar"]).should eq("/foo/bar")
    File.join(["foo", "bar", "baz"]).should eq("foo/bar/baz")
    File.join(["foo", "//bar//", "baz///"]).should eq("foo//bar//baz///")
    File.join(["/foo/", "/bar/", "/baz/"]).should eq("/foo/bar/baz/")
    File.join(["", "foo"]).should eq("foo")
    File.join(["foo", ""]).should eq("foo/")
    File.join(["", "", "foo"]).should eq("foo")
    File.join(["foo", "", "bar"]).should eq("foo/bar")
    File.join(["foo", "", "", "bar"]).should eq("foo/bar")
    File.join(["foo", "/", "bar"]).should eq("foo/bar")
    File.join(["foo", "/", "/", "bar"]).should eq("foo/bar")
    File.join(["/", "/foo", "/", "bar/", "/"]).should eq("/foo/bar/")
    File.join(["foo"]).should eq("foo")
    File.join("foo").should eq("foo")
  end

  it "chown" do
    # changing owners requires special privileges, so we test that method calls do compile
    typeof(File.chown("/tmp/test"))
    typeof(File.chown("/tmp/test", uid: 1001, gid: 100, follow_symlinks: true))
  end

  describe "chmod" do
    it "changes file permissions" do
      path = datapath("chmod.txt")
      begin
        File.write(path, "")
        File.chmod(path, 0o775)
        File.info(path).permissions.should eq(normalize_permissions(0o775, directory: false))
      ensure
        File.delete(path) if File.exists?(path)
      end
    end

    it "changes dir permissions" do
      path = datapath("chmod")
      begin
        Dir.mkdir(path, 0o775)
        File.chmod(path, 0o664)
        File.info(path).permissions.should eq(normalize_permissions(0o664, directory: true))
      ensure
        Dir.rmdir(path) if Dir.exists?(path)
      end
    end

    it "can take File::Permissions" do
      path = datapath("chmod.txt")
      begin
        File.write(path, "")
        File.chmod(path, File::Permissions.flags(OwnerAll, GroupAll, OtherExecute, OtherRead))
        File.info(path).permissions.should eq(normalize_permissions(0o775, directory: false))
      ensure
        File.delete(path) if File.exists?(path)
      end
    end

    # See TODO in win32 Crystal::System::File.chmod
    pending_win32 "follows symlinks" do
      with_tempfile("chmod-destination.txt", "chmod-source.txt") do |source_path, target_path|
        File.write(source_path, "")

        File.symlink(File.real_path(source_path), target_path)
        File.symlink?(target_path).should be_true

        File.chmod(target_path, 0o444)

        File.info(target_path).permissions.should eq(normalize_permissions(0o444, directory: false))
      end
    end

    it "raises when destination doesn't exist" do
      expect_raises_errno(Errno::ENOENT, "Error changing permissions of '#{datapath("unknown_chmod_path.txt")}'") do
        File.chmod(datapath("unknown_chmod_path.txt"), 0o664)
      end
    end
  end

  it "gets info for this file" do
    info = File.info(datapath("test_file.txt"))
    info.type.should eq(File::Type::File)
  end

  it "gets info for this directory" do
    info = File.info(datapath)
    info.type.should eq(File::Type::Directory)
  end

  # TODO: support stating nul on windows
  pending_win32 "gets info for a character device" do
    info = File.info(File::NULL)
    info.type.should eq(File::Type::CharacterDevice)
  end

  it "gets info for a symlink" do
    info = File.info(datapath("symlink.txt"), follow_symlinks: false)
    info.type.should eq(File::Type::Symlink)
  end

  it "gets info for open file" do
    File.open(datapath("test_file.txt"), "r") do |file|
      info = file.info
      info.type.should eq(File::Type::File)
    end
  end

  it "gets info for pipe" do
    IO.pipe do |r, w|
      r.info.type.should eq(File::Type::Pipe)
      w.info.type.should eq(File::Type::Pipe)
    end
  end

  it "gets info for non-existent file and raises" do
    expect_raises_errno(Errno::ENOENT, "Unable to get info for 'non-existent'") do
      File.info("non-existent")
    end
  end

  it "gets info mtime for new file" do
    with_tempfile("mtime") do |path|
      File.touch(path)
      File.open(path) do |file|
        file.info.modification_time.should be_close(Time.utc, 1.seconds)
      end
      File.info(path).modification_time.should be_close(Time.utc, 1.seconds)
    end
  end

  describe "File::Info" do
    it "tests equal for the same file" do
      File.info(datapath("test_file.txt")).should eq(File.info(datapath("test_file.txt")))
    end

    it "tests equal for the same directory" do
      File.info(datapath("dir")).should eq(File.info(datapath("dir")))
    end

    it "tests unequal for different files" do
      File.info(datapath("test_file.txt")).should_not eq(File.info(datapath("test_file.ini")))
    end

    it "tests unequal for file and directory" do
      File.info(datapath("dir")).should_not eq(File.info(datapath("test_file.txt")))
    end
  end

  describe "size" do
    it { File.size(datapath("test_file.txt")).should eq(240) }
    it do
      File.open(datapath("test_file.txt"), "r") do |file|
        file.size.should eq(240)
      end
    end

    it "raises an error when the file does not exist" do
      filename = datapath("non_existing_file.txt")
      expect_raises_errno(Errno::ENOENT, "Error determining size of '#{filename}'") do
        File.size(filename)
      end
    end

    # TODO: do we even want this?
    pending_win32 "raises an error when a component of the path is a file" do
      expect_raises_errno(Errno::ENOTDIR, "Error determining size of '#{datapath("test_file.txt", "")}'") do
        File.size(datapath("test_file.txt", ""))
      end
    end
  end

  describe "delete" do
    it "deletes a file" do
      with_tempfile("delete-file.txt") do |filename|
        File.open(filename, "w") { }
        File.exists?(filename).should be_true
        File.delete(filename)
        File.exists?(filename).should be_false
      end
    end

    it "raises errno when file doesn't exist" do
      with_tempfile("nonexistant_file.txt") do |path|
        expect_raises_errno(Errno::ENOENT, "Error deleting file '#{path}'") do
          File.delete(path)
        end
      end
    end
  end

  describe "rename" do
    it "renames a file" do
      with_tempfile("rename-source.txt", "rename-target.txt") do |source_path, target_path|
        File.write(source_path, "hello")
        File.rename(source_path, target_path)
        File.exists?(source_path).should be_false
        File.exists?(target_path).should be_true
        File.read(target_path).strip.should eq("hello")
        File.delete(target_path)
      end
    end

    it "raises if old file doesn't exist" do
      with_tempfile("rename-fail-source.txt", "rename-fail-target.txt") do |source_path, target_path|
        expect_raises_errno(Errno::ENOENT, "Error renaming file '#{source_path}' to '#{target_path}'") do
          File.rename(source_path, target_path)
        end
      end
    end
  end

  # TODO: expand_path is horribly broken on win32
  describe "expand_path" do
    pending_win32 "converts a pathname to an absolute pathname" do
      File.expand_path("").should eq(base)
      File.expand_path("a").should eq(File.join([base, "a"]))
      File.expand_path("a", nil).should eq(File.join([base, "a"]))
    end

    pending_win32 "converts a pathname to an absolute pathname, Ruby-Talk:18512" do
      File.expand_path(".a").should eq(File.join([base, ".a"]))
      File.expand_path("..a").should eq(File.join([base, "..a"]))
      File.expand_path("a../b").should eq(File.join([base, "a../b"]))
    end

    pending_win32 "keeps trailing dots on absolute pathname" do
      File.expand_path("a.").should eq(File.join([base, "a."]))
      File.expand_path("a..").should eq(File.join([base, "a.."]))
    end

    pending_win32 "converts a pathname to an absolute pathname, using a complete path" do
      File.expand_path("", "#{tmpdir}").should eq("#{tmpdir}")
      File.expand_path("a", "#{tmpdir}").should eq("#{tmpdir}/a")
      File.expand_path("../a", "#{tmpdir}/xxx").should eq("#{tmpdir}/a")
      File.expand_path(".", "#{rootdir}").should eq("#{rootdir}")
    end

    pending_win32 "expands a path with multi-byte characters" do
      File.expand_path("Ångström").should eq("#{base}/Ångström")
    end

    pending_win32 "expands /./dir to /dir" do
      File.expand_path("/./dir").should eq("/dir")
    end

    pending_win32 "replaces multiple / with a single /" do
      File.expand_path("////some/path").should eq("/some/path")
      File.expand_path("/some////path").should eq("/some/path")
    end

    pending_win32 "expand path with" do
      File.expand_path("../../bin", "/tmp/x").should eq("/bin")
      File.expand_path("../../bin", "/tmp").should eq("/bin")
      File.expand_path("../../bin", "/").should eq("/bin")
      File.expand_path("../bin", "tmp/x").should eq(File.join([base, "tmp", "bin"]))
      File.expand_path("../bin", "x/../tmp").should eq(File.join([base, "bin"]))
    end

    it "expand_path for commoms unix path  give a full path" do
      File.expand_path("/tmp/").should eq("/tmp/")
      File.expand_path("/tmp/../../../tmp").should eq("/tmp")
      File.expand_path("").should eq(base)
      File.expand_path("./////").should eq(File.join(base, ""))
      File.expand_path(".").should eq(base)
      File.expand_path(base).should eq(base)
    end

    it "converts a pathname to an absolute pathname, using ~ (home) as base" do
      File.expand_path("~/", home: true).should eq(File.join(home, ""))
      File.expand_path("~/..badfilename", home: true).should eq(File.join(home, "..badfilename"))
      File.expand_path("..", home: true).should eq("/#{base.split('/')[0...-1].join('/')}".gsub(%r{\A//}, "/"))
      File.expand_path("~/a", "~/b", home: true).should eq(File.join(home, "a"))
      File.expand_path("~", home: true).should eq(home)
      File.expand_path("~", "/tmp/gumby/ddd", home: true).should eq(home)
      File.expand_path("~/a", "/tmp/gumby/ddd", home: true).should eq(File.join([home, "a"]))
    end

    it "converts a pathname to an absolute pathname, using ~ (home) as base (trailing /)" do
      prev_home = home
      begin
        ENV["HOME"] = File.expand_path(datapath)
        File.expand_path("~/", home: true).should eq(File.join(home, ""))
        File.expand_path("~/..badfilename", home: true).should eq(File.join(home, "..badfilename"))
        File.expand_path("..", home: true).should eq("/#{base.split('/')[0...-1].join('/')}".gsub(%r{\A//}, "/"))
        File.expand_path("~/a", "~/b", home: true).should eq(File.join(home, "a"))
        File.expand_path("~", home: true).should eq(home)
        File.expand_path("~", "/tmp/gumby/ddd", home: true).should eq(home)
        File.expand_path("~/a", "/tmp/gumby/ddd", home: true).should eq(File.join([home, "a"]))
      ensure
        ENV["HOME"] = prev_home
      end
    end

    it "converts a pathname to an absolute pathname, using ~ (home) as base (HOME=/)" do
      prev_home = home
      begin
        ENV["HOME"] = "/"
        File.expand_path("~/", home: true).should eq(home)
        File.expand_path("~/..badfilename", home: true).should eq(File.join(home, "..badfilename"))
        File.expand_path("..", home: true).should eq("/#{base.split('/')[0...-1].join('/')}".gsub(/\A\/\//, "/"))
        File.expand_path("~/a", "~/b", home: true).should eq(File.join(home, "a"))
        File.expand_path("~", home: true).should eq(home)
        File.expand_path("~", "/tmp/gumby/ddd", home: true).should eq(home)
        File.expand_path("~/a", "/tmp/gumby/ddd", home: true).should eq(File.join([home, "a"]))
      ensure
        ENV["HOME"] = prev_home
      end
    end
  end

  describe "real_path" do
    it "expands paths for normal files" do
      {% if flag?(:win32) %}
        File.real_path("C:\\Windows").should eq(File.real_path("C:\\Windows"))
        File.real_path("C:\\Windows\\..").should eq(File.real_path("C:\\"))
      {% else %}
        File.real_path("/usr/share").should eq(File.real_path("/usr/share"))
        File.real_path("/usr/share/..").should eq(File.real_path("/usr"))
      {% end %}
    end

    it "raises Errno if file doesn't exist" do
      expect_raises_errno(Errno::ENOENT, "Error resolving real path of '/usr/share/foo/bar'") do
        File.real_path("/usr/share/foo/bar")
      end
    end

    # TODO: see Crystal::System::File.real_path TODO
    pending_win32 "expands paths of symlinks" do
      file_path = File.expand_path(datapath("test_file.txt"))
      with_tempfile("symlink.txt") do |symlink_path|
        File.symlink(file_path, symlink_path)
        real_symlink_path = File.real_path(symlink_path)
        real_file_path = File.real_path(file_path)
        real_symlink_path.should eq(real_file_path)
      end
    end
  end

  describe "write" do
    it "can write to a file" do
      with_tempfile("write.txt") do |path|
        File.write(path, "hello")
        File.read(path).should eq("hello")
      end
    end

    it "writes bytes" do
      with_tempfile("write-bytes.txt") do |path|
        File.write(path, "hello".to_slice)
        File.read(path).should eq("hello")
      end
    end

    it "writes io" do
      with_tempfile("write-io.txt") do |path|
        File.open(datapath("test_file.txt")) do |file|
          File.write(path, file)
        end
        File.read(path).should eq(File.read(datapath("test_file.txt")))
      end
    end

    it "raises if trying to write to a file not opened for writing" do
      with_tempfile("write-fails.txt") do |path|
        File.write(path, "hello")
        expect_raises(IO::Error, "File not open for writing") do
          File.open(path) { |file| file << "hello" }
        end
      end
    end

    it "can create a new file in append mode" do
      with_tempfile("append-create.txt") do |path|
        File.write(path, "hello", mode: "a")
        File.read(path).should eq("hello")
      end
    end

    it "can append to an existing file" do
      with_tempfile("append-existing.txt") do |path|
        File.write(path, "hello")
        File.read(path).should eq("hello")
        File.write(path, " world", mode: "a")
        File.read(path).should eq("hello world")
      end
    end
  end

  it "does to_s and inspect" do
    File.open(datapath("test_file.txt")) do |file|
      file.to_s.should eq("#<File:0x#{file.object_id.to_s(16)}>")
      file.inspect.should eq("#<File:#{datapath("test_file.txt")}>")
    end
  end

  describe "close" do
    it "is not closed when opening" do
      File.open(datapath("test_file.txt")) do |file|
        file.closed?.should be_false
      end
    end

    it "is closed when closed" do
      file = File.new(datapath("test_file.txt"))
      file.close
      file.closed?.should be_true
    end

    it "should not raise when closing twice" do
      file = File.new(datapath("test_file.txt"))
      file.close
      file.close
    end

    it "does to_s when closed" do
      file = File.new(datapath("test_file.txt"))
      file.close
      file.to_s.should eq("#<File:0x#{file.object_id.to_s(16)}>")
      file.inspect.should eq("#<File:#{datapath("test_file.txt")} (closed)>")
    end
  end

  it "opens with perm (int)" do
    with_tempfile("write_with_perm-int.txt") do |path|
      perm = 0o600
      File.open(path, "w", perm) do |file|
        file.info.permissions.should eq(normalize_permissions(perm, directory: false))
      end
    end
  end

  it "opens with perm (File::Permissions)" do
    with_tempfile("write_with_perm.txt") do |path|
      perm = File::Permissions.flags(OwnerRead, OwnerWrite)
      File.open(path, "w", perm) do |file|
        file.info.permissions.should eq(normalize_permissions(perm.value, directory: false))
      end
    end
  end

  it "clears the read buffer after a seek" do
    File.open(datapath("test_file.txt")) do |file|
      file.gets(5).should eq("Hello")
      file.seek(1)
      file.gets(4).should eq("ello")
    end
  end

  it "seeks from the current position" do
    File.open(datapath("test_file.txt")) do |file|
      file.gets(5)
      file.seek(-4, IO::Seek::Current)
      file.tell.should eq(1)
    end
  end

  it "raises if invoking seek with a closed file" do
    file = File.new(datapath("test_file.txt"))
    file.close
    expect_raises(IO::Error, "Closed stream") { file.seek(1) }
  end

  it "returns the current read position with tell" do
    File.open(datapath("test_file.txt")) do |file|
      file.tell.should eq(0)
      file.gets(5).should eq("Hello")
      file.tell.should eq(5)
      file.sync = true
      file.tell.should eq(5)
    end
  end

  it "can navigate with pos" do
    File.open(datapath("test_file.txt")) do |file|
      file.pos = 3
      file.gets(2).should eq("lo")
      file.pos -= 4
      file.gets(4).should eq("ello")
    end
  end

  it "raises if invoking tell with a closed file" do
    file = File.new(datapath("test_file.txt"))
    file.close
    expect_raises(IO::Error, "Closed stream") { file.tell }
  end

  it "iterates with each_char" do
    File.open(datapath("test_file.txt")) do |file|
      i = 0
      file.each_char do |char|
        case i
        when 0 then char.should eq('H')
        when 1 then char.should eq('e')
        else
          break
        end
        i += 1
      end
    end
  end

  it "iterates with each_byte" do
    File.open(datapath("test_file.txt")) do |file|
      i = 0
      file.each_byte do |byte|
        case i
        when 0 then byte.should eq('H'.ord)
        when 1 then byte.should eq('e'.ord)
        else
          break
        end
        i += 1
      end
    end
  end

  it "rewinds" do
    File.open(datapath("test_file.txt")) do |file|
      content = file.gets_to_end
      content.size.should_not eq(0)
      file.rewind
      file.gets_to_end.should eq(content)
    end
  end

  describe "truncate" do
    it "truncates" do
      with_tempfile("truncate.txt") do |path|
        File.write(path, "0123456789")
        File.open(path, "r+") do |f|
          f.gets_to_end.should eq("0123456789")
          f.rewind
          f.puts("333")
          f.truncate(4)
        end

        File.read(path).should eq("333\n")
      end
    end

    it "truncates completely when no size is passed" do
      with_tempfile("truncate-no_size.txt") do |path|
        File.write(path, "0123456789")
        File.open(path, "r+") do |f|
          f.puts("333")
          f.truncate
        end

        File.read(path).should eq("")
      end
    end

    it "requires a file opened for writing" do
      with_tempfile("truncate-opened.txt") do |path|
        File.write(path, "0123456789")
        File.open(path, "r") do |f|
          expect_raises_errno(Errno::EINVAL, "Error truncating file '#{path}'") do
            f.truncate(4)
          end
        end
      end
    end
  end

  describe "fsync" do
    it "syncs OS file buffer to disk" do
      with_tempfile("fsync.txt") do |path|
        File.open(path, "a") do |f|
          f.puts("333")
          f.fsync
          File.read(path).should eq("333\n")
        end
      end
    end
  end

  # TODO: implement flock on windows
  describe "flock" do
    pending_win32 "exlusively locks a file" do
      File.open(datapath("test_file.txt")) do |file1|
        File.open(datapath("test_file.txt")) do |file2|
          file1.flock_exclusive do
            # BUG: check for EWOULDBLOCK when exception filters are implemented
            expect_raises_errno(Errno::EAGAIN, "flock") do
              file2.flock_exclusive(blocking: false) { }
            end
          end
        end
      end
    end

    pending_win32 "shared locks a file" do
      File.open(datapath("test_file.txt")) do |file1|
        File.open(datapath("test_file.txt")) do |file2|
          file1.flock_shared do
            file2.flock_shared(blocking: false) { }
          end
        end
      end
    end
  end

  it "reads at offset" do
    filename = datapath("test_file.txt")
    File.open(filename) do |file|
      file.read_at(6, 100) do |io|
        io.gets_to_end.should eq("World\nHello World\nHello World\nHello World\nHello World\nHello World\nHello World\nHello World\nHello Worl")
      end
      file.read_at(0, 240) do |io|
        io.gets_to_end.should eq(File.read(filename))
      end
    end
  end

  it "raises when reading at offset outside of bounds" do
    with_tempfile("read-out_of_bounds") do |path|
      File.write(path, "hello world")

      begin
        File.open(path) do |io|
          expect_raises(ArgumentError, "Negative bytesize") do
            io.read_at(3, -1) { }
          end

          expect_raises(ArgumentError, "Offset out of bounds") do
            io.read_at(12, 1) { }
          end

          expect_raises(ArgumentError, "Bytesize out of bounds") do
            io.read_at(6, 6) { }
          end
        end
      end
    end
  end

  describe "raises on null byte" do
    it_raises_on_null_byte "new" do
      File.new("foo\0bar")
    end

    it_raises_on_null_byte "join" do
      File.join("foo", "\0bar")
    end

    it_raises_on_null_byte "size" do
      File.size("foo\0bar")
    end

    it_raises_on_null_byte "rename (first arg)" do
      File.rename("foo\0bar", "baz")
    end

    it_raises_on_null_byte "rename (second arg)" do
      File.rename("baz", "foo\0bar")
    end

    it_raises_on_null_byte "info" do
      File.info("foo\0bar")
    end

    it_raises_on_null_byte "info?" do
      File.info?("foo\0bar")
    end

    it_raises_on_null_byte "exists?" do
      File.exists?("foo\0bar")
    end

    it_raises_on_null_byte "readable?" do
      File.readable?("foo\0bar")
    end

    it_raises_on_null_byte "writable?" do
      File.writable?("foo\0bar")
    end

    pending_win32 "errors on executable?" do
      expect_raises(ArgumentError, "String contains null byte") do
        File.executable?("foo\0bar")
      end
    end

    it_raises_on_null_byte "file?" do
      File.file?("foo\0bar")
    end

    it_raises_on_null_byte "directory?" do
      File.directory?("foo\0bar")
    end

    it_raises_on_null_byte "dirname" do
      File.dirname("foo\0bar")
    end

    it_raises_on_null_byte "basename" do
      File.basename("foo\0bar")
    end

    it_raises_on_null_byte "basename 2, first arg" do
      File.basename("foo\0bar", "baz")
    end

    it_raises_on_null_byte "basename 2, second arg" do
      File.basename("foobar", "baz\0")
    end

    it_raises_on_null_byte "delete" do
      File.delete("foo\0bar")
    end

    it_raises_on_null_byte "extname" do
      File.extname("foo\0bar")
    end

    it_raises_on_null_byte "expand_path, first arg" do
      File.expand_path("foo\0bar")
    end

    it_raises_on_null_byte "expand_path, second arg" do
      File.expand_path("baz", "foo\0bar")
    end

    it_raises_on_null_byte "link, first arg" do
      File.link("foo\0bar", "baz")
    end

    it_raises_on_null_byte "link, second arg" do
      File.link("baz", "foo\0bar")
    end

    it_raises_on_null_byte "symlink, first arg" do
      File.symlink("foo\0bar", "baz")
    end

    it_raises_on_null_byte "symlink, second arg" do
      File.symlink("baz", "foo\0bar")
    end

    it_raises_on_null_byte "symlink?" do
      File.symlink?("foo\0bar")
    end
  end

  describe "#delete" do
    it "deletes" do
      path = datapath("file-to-be-deleted")
      File.touch(path)

      file = File.new path
      file.close

      File.exists?(path).should be_true
      file.delete
      File.exists?(path).should be_false
    ensure
      File.delete(path) if path && File.exists?(path)
    end
  end

  # TODO: these specs don't compile on win32 because iconv isn't implemented
  {% unless flag?(:win32) %}
    describe "encoding" do
      it "writes with encoding" do
        with_tempfile("encoding-write.txt") do |path|
          File.write(path, "hello", encoding: "UCS-2LE")
          File.read(path).to_slice.should eq("hello".encode("UCS-2LE"))
        end
      end

      it "reads with encoding" do
        with_tempfile("encoding-read.txt") do |path|
          File.write(path, "hello", encoding: "UCS-2LE")
          File.read(path, encoding: "UCS-2LE").should eq("hello")
        end
      end

      it "opens with encoding" do
        with_tempfile("encoding-open.txt") do |path|
          File.write(path, "hello", encoding: "UCS-2LE")
          File.open(path, encoding: "UCS-2LE") do |file|
            file.gets_to_end.should eq("hello")
          end
        end
      end

      it "does each line with encoding" do
        with_tempfile("encoding-each_line.txt") do |path|
          File.write(path, "hello", encoding: "UCS-2LE")
          File.each_line(path, encoding: "UCS-2LE") do |line|
            line.should eq("hello")
          end
        end
      end

      it "reads lines with encoding" do
        with_tempfile("encoding-read_lines.txt") do |path|
          File.write(path, "hello", encoding: "UCS-2LE")
          File.read_lines(path, encoding: "UCS-2LE").should eq(["hello"])
        end
      end
    end
  {% end %}

  describe "closed stream" do
    it "raises if writing on a closed stream" do
      io = File.open(datapath("test_file.txt"), "r")
      io.close

      expect_raises(IO::Error, "Closed stream") { io.gets_to_end }
      expect_raises(IO::Error, "Closed stream") { io.print "hi" }
      expect_raises(IO::Error, "Closed stream") { io.puts "hi" }
      expect_raises(IO::Error, "Closed stream") { io.seek(1) }
      expect_raises(IO::Error, "Closed stream") { io.gets }
      expect_raises(IO::Error, "Closed stream") { io.read_byte }
      expect_raises(IO::Error, "Closed stream") { io.write_byte('a'.ord.to_u8) }
    end
  end

  describe "utime" do
    it "sets times with utime" do
      with_tempfile("utime-set.txt") do |path|
        File.write(path, "")

        atime = Time.utc(2000, 1, 2)
        mtime = Time.utc(2000, 3, 4)

        File.utime(atime, mtime, path)

        info = File.info(path)
        info.modification_time.should eq(mtime)
      end
    end

    it "raises if file not found" do
      atime = Time.utc(2000, 1, 2)
      mtime = Time.utc(2000, 3, 4)

      expect_raises_errno(Errno::ENOENT, "Error setting time on file '#{datapath("nonexistent_file.txt")}'") do
        File.utime(atime, mtime, datapath("nonexistent_file.txt"))
      end
    end
  end

  describe "touch" do
    it "creates file if it doesn't exist" do
      with_tempfile("touch-create.txt") do |path|
        File.exists?(path).should be_false
        File.touch(path)
        File.exists?(path).should be_true
      end
    end

    it "sets file times to given time" do
      time = Time.utc(2000, 3, 4)
      with_tempfile("touch-times.txt") do |path|
        File.touch(path, time)

        info = File.info(path)
        info.modification_time.should eq(time)
      end
    end

    it "sets file times to current time if no time argument given" do
      with_tempfile("touch-time_now.txt") do |path|
        File.touch(path)

        info = File.info(path)
        info.modification_time.should be_close(Time.utc, 1.second)
      end
    end

    it "raises if path contains non-existent directory" do
      with_tempfile(File.join("nonexistant-dir", "touch.txt")) do |path|
        expect_raises_errno(Errno::ENOENT, "Error opening file '#{path}'") do
          File.touch(path)
        end
      end
    end

    # TODO: there is no file which is reliably unwritable on windows
    pending_win32 "raises if file cannot be accessed" do
      expect_raises_errno(Errno::EPERM, "Error setting time on file '/bin/ls'") do
        File.touch("/bin/ls")
      end
    end
  end

  describe ".match?" do
    it "matches basics" do
      File.match?("abc", "abc").should be_true
      File.match?("*", "abc").should be_true
      File.match?("*c", "abc").should be_true
      File.match?("a*", "a").should be_true
      File.match?("a*", "abc").should be_true
      File.match?("a*/b", "abc/b").should be_true
      File.match?("*x", "xxx").should be_true
    end
    it "matches multiple expansions" do
      File.match?("a*b*c*d*e*/f", "axbxcxdxe/f").should be_true
      File.match?("a*b*c*d*e*/f", "axbxcxdxexxx/f").should be_true
      File.match?("a*b?c*x", "abxbbxdbxebxczzx").should be_true
      File.match?("a*b?c*x", "abxbbxdbxebxczzy").should be_false
    end
    it "matches unicode characters" do
      File.match?("a?b", "a☺b").should be_true
      File.match?("a???b", "a☺b").should be_false
    end
    it "* don't match /" do
      File.match?("a*", "ab/c").should be_false
      File.match?("a*/b", "a/c/b").should be_false
      File.match?("a*b*c*d*e*/f", "axbxcxdxe/xxx/f").should be_false
      File.match?("a*b*c*d*e*/f", "axbxcxdxexxx/fff").should be_false
    end
    it "** matches /" do
      File.match?("a**", "ab/c").should be_true
      File.match?("a**/b", "a/c/b").should be_true
      File.match?("a*b*c*d*e**/f", "axbxcxdxe/xxx/f").should be_true
      File.match?("a*b*c*d*e**/f", "axbxcxdxexxx/f").should be_true
      File.match?("a*b*c*d*e**/f", "axbxcxdxexxx/fff").should be_false
    end
    it "classes" do
      File.match?("ab[c]", "abc").should be_true
      File.match?("ab[b-d]", "abc").should be_true
      File.match?("ab[d-b]", "abc").should be_false
      File.match?("ab[e-g]", "abc").should be_false
      File.match?("ab[e-gc]", "abc").should be_true
      File.match?("ab[^c]", "abc").should be_false
      File.match?("ab[^b-d]", "abc").should be_false
      File.match?("ab[^e-g]", "abc").should be_true
      File.match?("a[^a]b", "a☺b").should be_true
      File.match?("a[^a][^a][^a]b", "a☺b").should be_false
      File.match?("[a-ζ]*", "α").should be_true
      File.match?("*[a-ζ]", "A").should be_false
    end
    it "escape" do
      File.match?("a\\*b", "a*b").should be_true
      File.match?("a\\*b", "ab").should be_false
      File.match?("a\\**b", "a*bb").should be_true
      File.match?("a\\**b", "abb").should be_false
      File.match?("a*\\*b", "ab*b").should be_true
      File.match?("a*\\*b", "abb").should be_false
    end
    it "special chars" do
      File.match?("a?b", "a/b").should be_false
      File.match?("a*b", "a/b").should be_false
    end
    it "classes escapes" do
      File.match?("[\\]a]", "]").should be_true
      File.match?("[\\-]", "-").should be_true
      File.match?("[x\\-]", "x").should be_true
      File.match?("[x\\-]", "-").should be_true
      File.match?("[x\\-]", "z").should be_false
      File.match?("[\\-x]", "x").should be_true
      File.match?("[\\-x]", "-").should be_true
      File.match?("[\\-x]", "a").should be_false
      expect_raises(File::BadPatternError, "empty character set") do
        File.match?("[]a]", "]")
      end
      expect_raises(File::BadPatternError, "missing range start") do
        File.match?("[-]", "-")
      end
      expect_raises(File::BadPatternError, "missing range end") do
        File.match?("[x-]", "x")
      end
      expect_raises(File::BadPatternError, "missing range start") do
        File.match?("[-x]", "x")
      end
      expect_raises(File::BadPatternError, "Empty escape character") do
        File.match?("\\", "a")
      end
      expect_raises(File::BadPatternError, "missing range start") do
        File.match?("[a-b-c]", "a")
      end
      expect_raises(File::BadPatternError, "unterminated character set") do
        File.match?("[", "a")
      end
      expect_raises(File::BadPatternError, "unterminated character set") do
        File.match?("[^", "a")
      end
      expect_raises(File::BadPatternError, "unterminated character set") do
        File.match?("[^bc", "a")
      end
      expect_raises(File::BadPatternError, "unterminated character set") do
        File.match?("a[", "a")
      end
    end
    it "alternates" do
      File.match?("{abc,def}", "abc").should be_true
      File.match?("ab{c,}", "abc").should be_true
      File.match?("ab{c,}", "ab").should be_true
      File.match?("ab{d,e}", "abc").should be_false
      File.match?("ab{*,/cde}", "abcde").should be_true
      File.match?("ab{*,/cde}", "ab/cde").should be_true
      File.match?("ab{?,/}de", "abcde").should be_true
      File.match?("ab{?,/}de", "ab/de").should be_true
      File.match?("ab{{c,d}ef,}", "ab").should be_true
      File.match?("ab{{c,d}ef,}", "abcef").should be_true
      File.match?("ab{{c,d}ef,}", "abdef").should be_true
    end
  end

  describe File::Permissions do
    it "does to_s" do
      perm = File::Permissions.flags(OwnerAll, GroupRead, GroupWrite, OtherRead)
      perm.to_s.should eq("rwxrw-r-- (0o764)")
      perm.inspect.should eq("rwxrw-r-- (0o764)")
      perm.pretty_inspect.should eq("rwxrw-r-- (0o764)")
    end
  end
end
