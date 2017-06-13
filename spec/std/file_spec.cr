require "spec"
require "tempfile"

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

private def it_raises_on_null_byte(operation, &block)
  it "errors on #{operation}" do
    expect_raises(ArgumentError, "String contains null byte") do
      block.call
    end
  end
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

  {% if flag?(:linux) %}
    it "reads entire file from proc virtual filesystem" do
      str1 = File.open "/proc/self/cmdline", &.gets_to_end
      str2 = File.read "/proc/self/cmdline"
      str2.empty?.should be_false
      str2.should eq(str1)
    end
  {% end %}

  it "reads lines from file" do
    lines = File.read_lines "#{__DIR__}/data/test_file.txt"
    lines.size.should eq(20)
    lines.first.should eq("Hello World")
  end

  it "reads lines from file with chomp = false" do
    lines = File.read_lines "#{__DIR__}/data/test_file.txt", chomp: false
    lines.size.should eq(20)
    lines.first.should eq("Hello World\n")
  end

  it "reads lines from file with each" do
    idx = 0
    File.each_line("#{__DIR__}/data/test_file.txt") do |line|
      if idx == 0
        line.should eq("Hello World")
      end
      idx += 1
    end
    idx.should eq(20)
  end

  it "reads lines from file with each, chomp = false" do
    idx = 0
    File.each_line("#{__DIR__}/data/test_file.txt", chomp: false) do |line|
      if idx == 0
        line.should eq("Hello World\n")
      end
      idx += 1
    end
    idx.should eq(20)
  end

  it "reads lines from file with each as iterator" do
    idx = 0
    File.each_line("#{__DIR__}/data/test_file.txt").each do |line|
      if idx == 0
        line.should eq("Hello World")
      end
      idx += 1
    end
    idx.should eq(20)
  end

  it "reads lines from file with each as iterator, chomp = false" do
    idx = 0
    File.each_line("#{__DIR__}/data/test_file.txt", chomp: false).each do |line|
      if idx == 0
        line.should eq("Hello World\n")
      end
      idx += 1
    end
    idx.should eq(20)
  end

  describe "empty?" do
    it "gives true when file is empty" do
      File.empty?("#{__DIR__}/data/blank_test_file.txt").should be_true
    end

    it "gives false when file is not empty" do
      File.empty?("#{__DIR__}/data/test_file.txt").should be_false
    end

    it "raises an error when the file does not exist" do
      filename = "#{__DIR__}/data/non_existing_file.txt"
      expect_raises Errno do
        File.empty?(filename)
      end
    end
  end

  describe "exists?" do
    it "gives true" do
      File.exists?("#{__DIR__}/data/test_file.txt").should be_true
    end

    it "gives false" do
      File.exists?("#{__DIR__}/data/non_existing_file.txt").should be_false
    end
  end

  describe "executable?" do
    it "gives false" do
      File.executable?("#{__DIR__}/data/test_file.txt").should be_false
    end
  end

  describe "readable?" do
    it "gives true" do
      File.readable?("#{__DIR__}/data/test_file.txt").should be_true
    end
  end

  describe "writable?" do
    it "gives true" do
      File.writable?("#{__DIR__}/data/test_file.txt").should be_true
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

  describe "link" do
    it "creates a hard link" do
      out_path = "#{__DIR__}/data/test_file_link.txt"
      begin
        File.link("#{__DIR__}/data/test_file.txt", out_path)
        File.exists?(out_path).should be_true
        File.symlink?(out_path).should be_false
      ensure
        File.delete(out_path) if File.exists?(out_path)
      end
    end
  end

  describe "symlink" do
    it "creates a symbolic link" do
      out_path = "#{__DIR__}/data/test_file_symlink.txt"
      begin
        File.symlink("#{__DIR__}/data/test_file.txt", out_path)
        File.symlink?(out_path).should be_true
      ensure
        File.delete(out_path) if File.exists?(out_path)
      end
    end
  end

  describe "symlink?" do
    it "gives true" do
      File.symlink?("#{__DIR__}/data/symlink.txt").should be_true
    end

    it "gives false" do
      File.symlink?("#{__DIR__}/data/test_file.txt").should be_false
      File.symlink?("#{__DIR__}/data/unknown_file.txt").should be_false
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
    File.extname("/foo/bar/baz.cr").should eq(".cr")
    File.extname("/foo/bar/baz.cr.cz").should eq(".cz")
    File.extname("/foo/bar/.profile").should eq("")
    File.extname("/foo/bar/.profile.sh").should eq(".sh")
    File.extname("/foo/bar/foo.").should eq("")
    File.extname("test").should eq("")
  end

  it "constructs a path from parts" do
    File.join(["///foo", "bar"]).should eq("///foo/bar")
    File.join(["///foo", "//bar"]).should eq("///foo//bar")
    File.join(["/foo/", "/bar"]).should eq("/foo/bar")
    File.join(["foo", "bar", "baz"]).should eq("foo/bar/baz")
    File.join(["foo", "//bar//", "baz///"]).should eq("foo//bar//baz///")
    File.join(["/foo/", "/bar/", "/baz/"]).should eq("/foo/bar/baz/")
  end

  it "chown" do
    # changing owners requires special privileges, so we test that method calls do compile
    typeof(File.chown("/tmp/test"))
    typeof(File.chown("/tmp/test", uid: 1001, gid: 100, follow_symlinks: true))
  end

  describe "chmod" do
    it "changes file permissions" do
      path = "#{__DIR__}/data/chmod.txt"
      begin
        File.write(path, "")
        File.chmod(path, 0o775)
        File.stat(path).perm.should eq(0o775)
      ensure
        File.delete(path) if File.exists?(path)
      end
    end

    it "changes dir permissions" do
      path = "#{__DIR__}/data/chmod"
      begin
        Dir.mkdir(path, 0o775)
        File.chmod(path, 0o664)
        File.stat(path).perm.should eq(0o664)
      ensure
        Dir.rmdir(path) if Dir.exists?(path)
      end
    end

    it "follows symlinks" do
      path = "#{__DIR__}/data/chmod_destination.txt"
      link = "#{__DIR__}/data/chmod.txt"
      begin
        File.write(path, "")
        File.symlink(path, link)
        File.chmod(link, 0o775)
        File.stat(link).perm.should eq(0o775)
      ensure
        File.delete(path) if File.exists?(path)
        File.delete(link) if File.symlink?(link)
      end
    end

    it "raises when destination doesn't exist" do
      expect_raises(Errno) do
        File.chmod("#{__DIR__}/data/unknown_chmod_path.txt", 0o664)
      end
    end
  end

  it "gets stat for this file" do
    stat = File.stat(__FILE__)
    stat.blockdev?.should be_false
    stat.chardev?.should be_false
    stat.directory?.should be_false
    stat.file?.should be_true
    stat.symlink?.should be_false
    stat.socket?.should be_false
  end

  it "gets stat for this directory" do
    stat = File.stat(__DIR__)
    stat.blockdev?.should be_false
    stat.chardev?.should be_false
    stat.directory?.should be_true
    stat.file?.should be_false
    stat.symlink?.should be_false
    stat.socket?.should be_false
  end

  it "gets stat for a character device" do
    stat = File.stat("/dev/null")
    stat.blockdev?.should be_false
    stat.chardev?.should be_true
    stat.directory?.should be_false
    stat.file?.should be_false
    stat.symlink?.should be_false
    stat.socket?.should be_false
  end

  it "gets stat for a symlink" do
    stat = File.lstat("#{__DIR__}/data/symlink.txt")
    stat.blockdev?.should be_false
    stat.chardev?.should be_false
    stat.directory?.should be_false
    stat.file?.should be_false
    stat.symlink?.should be_true
    stat.socket?.should be_false
  end

  it "gets stat for open file" do
    File.open(__FILE__, "r") do |file|
      stat = file.stat
      stat.blockdev?.should be_false
      stat.chardev?.should be_false
      stat.directory?.should be_false
      stat.file?.should be_true
      stat.symlink?.should be_false
      stat.socket?.should be_false
      stat.pipe?.should be_false
    end
  end

  it "gets stat for pipe" do
    IO.pipe do |r, w|
      r.stat.pipe?.should be_true
      w.stat.pipe?.should be_true
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
      (tmp.stat.atime - Time.utc_now).total_seconds.should be < 5
      (tmp.stat.ctime - Time.utc_now).total_seconds.should be < 5
      (tmp.stat.mtime - Time.utc_now).total_seconds.should be < 5
    ensure
      tmp.delete
    end
  end

  describe "size" do
    it { File.size("#{__DIR__}/data/test_file.txt").should eq(240) }
    it do
      File.open("#{__DIR__}/data/test_file.txt", "r") do |file|
        file.size.should eq(240)
      end
    end
  end

  describe "delete" do
    it "deletes a file" do
      filename = "#{__DIR__}/data/temp1.txt"
      File.open(filename, "w") { }
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
      File.expand_path("/some////path").should eq("/some/path")
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
      File.expand_path("~/..badfilename").should eq(File.join(home, "..badfilename"))
      File.expand_path("..").should eq("/#{base.split("/")[0...-1].join("/")}".gsub(%r{\A//}, "/"))
      File.expand_path("~/a", "~/b").should eq(File.join(home, "a"))
      File.expand_path("~").should eq(home)
      File.expand_path("~", "/tmp/gumby/ddd").should eq(home)
      File.expand_path("~/a", "/tmp/gumby/ddd").should eq(File.join([home, "a"]))
    end

    it "converts a pathname to an absolute pathname, using ~ (home) as base (trailing /)" do
      prev_home = home
      begin
        ENV["HOME"] = __DIR__ + "/"
        File.expand_path("~/").should eq(home)
        File.expand_path("~/..badfilename").should eq(File.join(home, "..badfilename"))
        File.expand_path("..").should eq("/#{base.split("/")[0...-1].join("/")}".gsub(%r{\A//}, "/"))
        File.expand_path("~/a", "~/b").should eq(File.join(home, "a"))
        File.expand_path("~").should eq(home)
        File.expand_path("~", "/tmp/gumby/ddd").should eq(home)
        File.expand_path("~/a", "/tmp/gumby/ddd").should eq(File.join([home, "a"]))
      ensure
        ENV["HOME"] = prev_home
      end
    end

    it "converts a pathname to an absolute pathname, using ~ (home) as base (HOME=/)" do
      prev_home = home
      begin
        ENV["HOME"] = "/"
        File.expand_path("~/").should eq(home)
        File.expand_path("~/..badfilename").should eq(File.join(home, "..badfilename"))
        File.expand_path("..").should eq("/#{base.split("/")[0...-1].join("/")}".gsub(%r{\A//}, "/"))
        File.expand_path("~/a", "~/b").should eq(File.join(home, "a"))
        File.expand_path("~").should eq(home)
        File.expand_path("~", "/tmp/gumby/ddd").should eq(home)
        File.expand_path("~/a", "/tmp/gumby/ddd").should eq(File.join([home, "a"]))
      ensure
        ENV["HOME"] = prev_home
      end
    end
  end

  describe "real_path" do
    it "expands paths for normal files" do
      File.real_path("/usr/share").should eq("/usr/share")
      File.real_path("/usr/share/..").should eq("/usr")
    end

    it "raises Errno if file doesn't exist" do
      expect_raises Errno do
        File.real_path("/usr/share/foo/bar")
      end
    end

    it "expands paths of symlinks" do
      symlink_path = "/tmp/test_file_symlink.txt"
      file_path = "#{__DIR__}/data/test_file.txt"
      begin
        File.symlink(file_path, symlink_path)
        real_symlink_path = File.real_path(symlink_path)
        real_file_path = File.real_path(file_path)
        real_symlink_path.should eq(real_file_path)
      ensure
        File.delete(symlink_path) if File.exists?(symlink_path)
      end
    end
  end

  describe "write" do
    it "can write to a file" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "hello")
      File.read(filename).should eq("hello")
      File.delete(filename)
    end

    it "writes bytes" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "hello".to_slice)
      File.read(filename).should eq("hello")
      File.delete(filename)
    end

    it "writes io" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.open("#{__DIR__}/data/test_file.txt") do |file|
        File.write(filename, file)
      end
      File.read(filename).should eq(File.read("#{__DIR__}/data/test_file.txt"))
      File.delete(filename)
    end

    it "raises if trying to write to a file not opened for writing" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "hello")
      expect_raises(IO::Error, "File not open for writing") do
        File.open(filename) { |file| file << "hello" }
      end
      File.delete(filename)
    end
  end

  it "does to_s" do
    file = File.new(__FILE__)
    file.to_s.should eq("#<File:0x#{file.object_id.to_s(16)}>")
    File.new(__FILE__).inspect.should eq("#<File:#{__FILE__}>")
  end

  describe "close" do
    it "is not closed when opening" do
      file = File.new(__FILE__)
      file.closed?.should be_false
    end

    it "is closed when closed" do
      file = File.new(__FILE__)
      file.close
      file.closed?.should be_true
    end

    it "should not raise when closing twice" do
      file = File.new(__FILE__)
      file.close
      file.close
    end

    it "does to_s when closed" do
      file = File.new(__FILE__)
      file.close
      file.to_s.should eq("#<File:0x#{file.object_id.to_s(16)}>")
      file.inspect.should eq("#<File:#{__FILE__} (closed)>")
    end
  end

  it "opens with perm" do
    filename = "#{__DIR__}/data/temp_write.txt"
    perm = 0o600
    File.open(filename, "w", perm) do |file|
      file.stat.perm.should eq(perm)
    end
    File.delete filename
  end

  it "clears the read buffer after a seek" do
    file = File.new("#{__DIR__}/data/test_file.txt")
    file.gets(5).should eq("Hello")
    file.seek(1)
    file.gets(4).should eq("ello")
  end

  it "seeks from the current position" do
    file = File.new("#{__DIR__}/data/test_file.txt")
    file.gets(5)
    file.seek(-4, IO::Seek::Current)
    file.tell.should eq(1)
  end

  it "raises if invoking seek with a closed file" do
    file = File.new("#{__DIR__}/data/test_file.txt")
    file.close
    expect_raises(IO::Error, "Closed stream") { file.seek(1) }
  end

  it "returns the current read position with tell" do
    file = File.new("#{__DIR__}/data/test_file.txt")
    file.tell.should eq(0)
    file.gets(5).should eq("Hello")
    file.tell.should eq(5)
    file.sync = true
    file.tell.should eq(5)
  end

  it "can navigate with pos" do
    file = File.new("#{__DIR__}/data/test_file.txt")
    file.pos = 3
    file.gets(2).should eq("lo")
    file.pos -= 4
    file.gets(4).should eq("ello")
  end

  it "raises if invoking tell with a closed file" do
    file = File.new("#{__DIR__}/data/test_file.txt")
    file.close
    expect_raises(IO::Error, "Closed stream") { file.tell }
  end

  it "iterates with each_char" do
    file = File.new("#{__DIR__}/data/test_file.txt")
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

  it "iterates with each_byte" do
    file = File.new("#{__DIR__}/data/test_file.txt")
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

  it "rewinds" do
    file = File.new("#{__DIR__}/data/test_file.txt")
    content = file.gets_to_end
    content.size.should_not eq(0)
    file.rewind
    file.gets_to_end.should eq(content)
  end

  describe "truncate" do
    it "truncates" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "0123456789")
      File.open(filename, "r+") do |f|
        f.gets_to_end.should eq("0123456789")
        f.rewind
        f.puts("333")
        f.truncate(4)
      end

      File.read(filename).should eq("333\n")
      File.delete filename
    end

    it "truncates completely when no size is passed" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "0123456789")
      File.open(filename, "r+") do |f|
        f.puts("333")
        f.truncate
      end

      File.read(filename).should eq("")
      File.delete filename
    end

    it "requires a file opened for writing" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "0123456789")
      File.open(filename, "r") do |f|
        expect_raises(Errno) do
          f.truncate(4)
        end
      end
      File.delete filename
    end
  end

  describe "flock" do
    it "exlusively locks a file" do
      File.open(__FILE__) do |file1|
        File.open(__FILE__) do |file2|
          file1.flock_exclusive do
            # BUG: check for EWOULDBLOCK when exception filters are implemented
            expect_raises(Errno) do
              file2.flock_exclusive(blocking: false) { }
            end
          end
        end
      end
    end

    it "shared locks a file" do
      File.open(__FILE__) do |file1|
        File.open(__FILE__) do |file2|
          file1.flock_shared do
            file2.flock_shared(blocking: false) { }
          end
        end
      end
    end
  end

  it "reads at offset" do
    filename = "#{__DIR__}/data/test_file.txt"
    file = File.open(filename)
    file.read_at(6, 100) do |io|
      io.gets_to_end.should eq("World\nHello World\nHello World\nHello World\nHello World\nHello World\nHello World\nHello World\nHello Worl")
    end
    file.read_at(0, 240) do |io|
      io.gets_to_end.should eq(File.read(filename))
    end
  end

  it "raises when reading at offset outside of bounds" do
    filename = "#{__DIR__}/data/temp_write.txt"
    File.write(filename, "hello world")

    begin
      File.open(filename) do |io|
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
    ensure
      File.delete(filename)
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

    it_raises_on_null_byte "stat" do
      File.stat("foo\0bar")
    end

    it_raises_on_null_byte "lstat" do
      File.lstat("foo\0bar")
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

    it_raises_on_null_byte "executable?" do
      File.executable?("foo\0bar")
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

  describe "encoding" do
    it "writes with encoding" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "hello", encoding: "UCS-2LE")
      File.read(filename).to_slice.should eq("hello".encode("UCS-2LE"))
      File.delete(filename)
    end

    it "reads with encoding" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "hello", encoding: "UCS-2LE")
      File.read(filename, encoding: "UCS-2LE").should eq("hello")
      File.delete(filename)
    end

    it "opens with encoding" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "hello", encoding: "UCS-2LE")
      File.open(filename, encoding: "UCS-2LE") do |file|
        file.gets_to_end.should eq("hello")
      end
      File.delete filename
    end

    it "does each line with encoding" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "hello", encoding: "UCS-2LE")
      File.each_line(filename, encoding: "UCS-2LE") do |line|
        line.should eq("hello")
      end
      File.delete filename
    end

    it "reads lines with encoding" do
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "hello", encoding: "UCS-2LE")
      File.read_lines(filename, encoding: "UCS-2LE").should eq(["hello"])
      File.delete filename
    end
  end

  describe "closed stream" do
    it "raises if writing on a closed stream" do
      io = File.open(__FILE__, "r")
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
      filename = "#{__DIR__}/data/temp_write.txt"
      File.write(filename, "")

      atime = Time.new(2000, 1, 2)
      mtime = Time.new(2000, 3, 4)

      File.utime(atime, mtime, filename)

      stat = File.stat(filename)
      stat.atime.should eq(atime)
      stat.mtime.should eq(mtime)

      File.delete filename
    end

    it "raises if file not found" do
      atime = Time.new(2000, 1, 2)
      mtime = Time.new(2000, 3, 4)

      expect_raises Errno, "Error setting time to file" do
        File.utime(atime, mtime, "#{__DIR__}/nonexistent_file")
      end
    end
  end

  describe "touch" do
    it "creates file if it doesn't exists" do
      filename = "#{__DIR__}/data/temp_touch.txt"
      begin
        File.exists?(filename).should be_false
        File.touch(filename)
        File.exists?(filename).should be_true
      ensure
        File.delete filename
      end
    end

    it "sets file times to given time" do
      filename = "#{__DIR__}/data/temp_touch.txt"
      time = Time.new(2000, 3, 4)
      begin
        File.touch(filename, time)

        stat = File.stat(filename)
        stat.atime.should eq(time)
        stat.mtime.should eq(time)
      ensure
        File.delete filename
      end
    end

    it "sets file times to Time.now if no time argument given" do
      filename = "#{__DIR__}/data/temp_touch.txt"
      time = Time.now
      begin
        File.touch(filename)

        stat = File.stat(filename)
        stat.atime.should be_close(time, 1.second)
        stat.mtime.should be_close(time, 1.second)
      ensure
        File.delete filename
      end
    end

    it "raises if path contains non-existent directory" do
      expect_raises Errno, "Error opening file" do
        File.touch("/tmp/non/existent/directory/test.tmp")
      end
    end

    it "raises if file cannot be accessed" do
      expect_raises Errno, "Operation not permitted" do
        File.touch("/bin/ls")
      end
    end
  end
end
