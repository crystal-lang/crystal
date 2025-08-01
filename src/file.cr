class File < IO::FileDescriptor
end

require "./file/error"
require "./file/match"
require "crystal/system/file"

# A `File` instance represents a file entry in the local file system and allows using it as an `IO`.
#
# ```
# file = File.new("path/to/file")
# content = file.gets_to_end
# file.close
#
# # Implicit close with `open` and a block:
# content = File.open("path/to/file") do |file|
#   file.gets_to_end
# end
#
# # Shortcut of the above:
# content = File.read("path/to/file")
#
# # Write to a file by opening with a "write mode" specified.
# File.open("path/to/file", "w") do |file|
#   file.print "hello"
# end
# # Content of file on disk will now be "hello".
#
# # Shortcut of the above:
# File.write("path/to/file", "hello")
# ```
#
# See `new` for various options *mode* can be.
#
# ## Temporary Files
#
# Every tempfile is operated as a `File`, including initializing, reading and writing.
#
# ```
# tempfile = File.tempfile("foo")
#
# File.size(tempfile.path)                   # => 6
# File.info(tempfile.path).modification_time # => 2015-10-20 13:11:12 UTC
# File.exists?(tempfile.path)                # => true
# File.read_lines(tempfile.path)             # => ["foobar"]
# ```
#
# Files created from `tempfile` are stored in a directory that handles
# temporary files (`Dir.tempdir`):
#
# ```
# File.tempfile("foo").path # => "/tmp/foo.ulBCPS"
# ```
#
# It is encouraged to delete a tempfile after using it, which
# ensures they are not left behind in your filesystem until garbage collected.
#
# ```
# tempfile = File.tempfile("foo")
# tempfile.delete
# ```
class File < IO::FileDescriptor
  # The file/directory separator character. `'/'` on all platforms.
  SEPARATOR = '/'

  # The file/directory separator string. `"/"` on all platforms.
  SEPARATOR_STRING = "/"

  # :nodoc:
  DEFAULT_CREATE_PERMISSIONS = File::Permissions.new(0o644)

  # The name of the null device on the host platform. `/dev/null` on UNIX and `NUL`
  # on win32.
  #
  # When this device is opened using `File.open`, read operations will always
  # return EOF, and any data written will be immediately discarded.
  #
  # ```
  # File.open(File::NULL, "w") do |file|
  #   file.puts "this is discarded"
  # end
  # ```
  NULL = {% if flag?(:win32) %}
           "NUL"
         {% else %}
           "/dev/null"
         {% end %}

  # Options used to control the behavior of `Dir.glob`.
  @[Flags]
  enum MatchOptions
    # Includes files whose name begins with a period (`.`).
    DotFiles

    # Includes files which have a hidden attribute backed by the native
    # filesystem.
    #
    # On Windows, this matches files that have the NTFS hidden attribute set.
    # This option alone doesn't match files with _both_ the hidden and the
    # system attributes, `OSHidden` must also be used.
    #
    # On other systems, this has no effect.
    NativeHidden

    # Includes files which are considered hidden by operating system
    # conventions (apart from `DotFiles`), but not by the filesystem.
    #
    # On Windows, this option alone has no effect. However, combining it with
    # `NativeHidden` matches files that have both the NTFS hidden and system
    # attributes set. Note that files with just the system attribute, but not
    # the hidden attribute, are always matched regardless of this option or
    # `NativeHidden`.
    #
    # On other systems, this has no effect.
    OSHidden

    # Returns a suitable platform-specific default set of options for
    # `Dir.glob` and `Dir.[]`.
    #
    # Currently this is always `NativeHidden | OSHidden`.
    def self.glob_default
      NativeHidden | OSHidden
    end
  end

  include Crystal::System::File

  # This constructor is for constructors to be able to initialize a `File` with
  # a *path* and *fd*. The *blocking* param is informational and must reflect
  # the non/blocking state of the underlying fd.
  private def initialize(@path, fd : Int, mode = "", blocking = nil, encoding = nil, invalid = nil)
    super(handle: fd)
    system_init(mode, blocking)
    set_encoding(encoding, invalid: invalid) if encoding
  end

  # Opens the file named by *filename*.
  #
  # *mode* must be one of the following file open modes:
  #
  # ```text
  # Mode       | Description
  # -----------+------------------------------------------------------
  # r rb       | Read-only, starts at the beginning of the file.
  # r+ r+b rb+ | Read-write, starts at the beginning of the file.
  # w wb       | Write-only, truncates existing file to zero length or
  #            | creates a new file if the file doesn't exist.
  # w+ w+b wb+ | Read-write, truncates existing file to zero length or
  #            | creates a new file if the file doesn't exist.
  # a ab       | Write-only, all writes seek to the end of the file,
  #            | creates a new file if the file doesn't exist.
  # a+ a+b ab+ | Read-write, all writes seek to the end of the file,
  #            | creates a new file if the file doesn't exist.
  # ```
  #
  # Line endings are preserved on all platforms. The `b` mode flag has no
  # effect; it is provided only for POSIX compatibility.
  #
  # NOTE: The *blocking* arg is deprecated since Crystal 1.17. It used to be
  # true by default to denote a regular disk file (always ready in system event
  # loops) and could be set to false when the file was known to be a fifo, pipe,
  # or character device (for example `/dev/tty`). The event loop now chooses
  # the appropriate blocking mode automatically and there are no reasons to
  # change it anymore.
  #
  # NOTE: On macOS files are always opened in blocking mode because non-blocking
  # FIFO files don't work — the OS exhibits issues with readiness notifications.
  {% begin %}
  def self.new(filename : Path | String, mode = "r", perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated] {% end %} blocking = nil)
    new_internal filename, mode, perm, encoding, invalid, blocking
  end
  {% end %}

  protected def self.new_internal(filename, mode = "r", perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil, blocking = nil)
    filename = filename.to_s
    fd, blocking = Crystal::System::File.open(filename, mode, perm: perm, blocking: blocking)
    new(filename, fd, mode, blocking, encoding, invalid)
  end

  getter path : String

  # Returns a `File::Info` object for the file given by *path* or returns `nil`
  # if the file does not exist.
  #
  # If *follow_symlinks* is set (the default), symbolic links are followed. Otherwise,
  # symbolic links return information on the symlink itself.
  #
  # ```
  # File.write("foo", "foo")
  # File.info?("foo").try(&.size) # => 3
  # File.info?("non_existent")    # => nil
  #
  # File.symlink("foo", "bar")
  # File.info?("bar", follow_symlinks: false).try(&.type.symlink?) # => true
  # ```
  #
  # Use `IO::FileDescriptor#info` if the file is already open.
  def self.info?(path : Path | String, follow_symlinks = true) : Info?
    Crystal::System::File.info?(path.to_s, follow_symlinks)
  end

  # Returns a `File::Info` object for the file given by *path* or raises
  # `File::Error` in case of an error.
  #
  # If *follow_symlinks* is set (the default), symbolic links are followed. Otherwise,
  # symbolic links return information on the symlink itself.
  #
  # ```
  # File.write("foo", "foo")
  # File.info("foo").size              # => 3
  # File.info("foo").modification_time # => 2015-09-23 06:24:19 UTC
  #
  # File.symlink("foo", "bar")
  # File.info("bar", follow_symlinks: false).type.symlink? # => true
  # ```
  #
  # Use `IO::FileDescriptor#info` if the file is already open.
  def self.info(path : Path | String, follow_symlinks = true) : Info
    Crystal::System::File.info(path.to_s, follow_symlinks)
  end

  # Returns whether the file given by *path* exists.
  #
  # Symbolic links are dereferenced, possibly recursively. Returns `false` if a
  # symbolic link refers to a non-existent file.
  #
  # ```
  # File.delete("foo") if File.exists?("foo")
  # File.exists?("foo") # => false
  # File.write("foo", "foo")
  # File.exists?("foo") # => true
  # ```
  def self.exists?(path : Path | String) : Bool
    Crystal::System::File.exists?(path.to_s)
  end

  # Returns `true` if *path1* and *path2* represents the same file.
  # The comparison take symlinks in consideration if *follow_symlinks* is `true`.
  def self.same?(path1 : Path | String, path2 : Path | String, follow_symlinks = false) : Bool
    info(path1.to_s, follow_symlinks).same_file? info(path2.to_s, follow_symlinks)
  end

  # Compares two files *filename1* to *filename2* to determine if they are identical.
  # Returns `true` if content are the same, `false` otherwise.
  #
  # ```
  # File.write("file.cr", "1")
  # File.write("bar.cr", "1")
  # File.same_content?("file.cr", "bar.cr") # => true
  # ```
  def self.same_content?(path1 : Path | String, path2 : Path | String) : Bool
    open_internal(path1, "rb") do |file1|
      open_internal(path2, "rb") do |file2|
        return false unless file1.size == file2.size

        same_content?(file1, file2)
      end
    end
  end

  # Returns the size of the file at *filename* in bytes.
  # Raises `File::NotFoundError` if the file at *filename* does not exist.
  #
  # ```
  # File.size("foo") # raises File::NotFoundError
  # File.write("foo", "foo")
  # File.size("foo") # => 3
  # ```
  def self.size(filename : Path | String) : Int64
    info(filename).size
  end

  # Returns `true` if the file at *path* is empty, otherwise returns `false`.
  # Raises `File::NotFoundError` if the file at *path* does not exist.
  #
  # ```
  # File.write("foo", "")
  # File.empty?("foo") # => true
  # File.write("foo", "foo")
  # File.empty?("foo") # => false
  # ```
  def self.empty?(path : Path | String) : Bool
    size(path) == 0
  end

  # Returns `true` if *path* is readable by the real user id of this process else returns `false`.
  #
  # ```
  # File.write("foo", "foo")
  # File.readable?("foo") # => true
  # ```
  @[Deprecated("Use `File::Info.readable?` instead")]
  def self.readable?(path : Path | String) : Bool
    Crystal::System::File.readable?(path.to_s)
  end

  # Returns `true` if *path* is writable by the real user id of this process else returns `false`.
  #
  # ```
  # File.write("foo", "foo")
  # File.writable?("foo") # => true
  # ```
  @[Deprecated("Use `File::Info.writable?` instead")]
  def self.writable?(path : Path | String) : Bool
    Crystal::System::File.writable?(path.to_s)
  end

  # Returns `true` if *path* is executable by the real user id of this process else returns `false`.
  #
  # ```
  # File.write("foo", "foo")
  # File.executable?("foo") # => false
  # ```
  @[Deprecated("Use `File::Info.executable?` instead")]
  def self.executable?(path : Path | String) : Bool
    Crystal::System::File.executable?(path.to_s)
  end

  # Returns `true` if given *path* exists and is a file.
  #
  # ```
  # File.write("foo", "")
  # Dir.mkdir("dir1")
  # File.file?("foo")    # => true
  # File.file?("dir1")   # => false
  # File.file?("foobar") # => false
  # ```
  def self.file?(path : Path | String) : Bool
    if info = info?(path)
      info.type.file?
    else
      false
    end
  end

  # Returns `true` if the given *path* exists and is a directory.
  #
  # ```
  # File.write("foo", "")
  # Dir.mkdir("dir2")
  # File.directory?("foo")    # => false
  # File.directory?("dir2")   # => true
  # File.directory?("foobar") # => false
  # ```
  def self.directory?(path : Path | String) : Bool
    Dir.exists?(path)
  end

  # Returns all components of the given *path* except the last one.
  #
  # ```
  # File.dirname("/foo/bar/file.cr") # => "/foo/bar"
  # ```
  def self.dirname(path : Path | String) : String
    Path.new(path).dirname
  end

  # Returns the last component of the given *path*.
  #
  # ```
  # File.basename("/foo/bar/file.cr") # => "file.cr"
  # ```
  def self.basename(path : Path | String) : String
    Path.new(path).basename
  end

  # Returns the last component of the given *path*.
  #
  # If *suffix* is present at the end of *path*, it is removed.
  #
  # ```
  # File.basename("/foo/bar/file.cr", ".cr") # => "file"
  # ```
  def self.basename(path : Path | String, suffix : String) : String
    Path.new(path).basename(suffix.check_no_null_byte)
  end

  # Changes the owner of the specified file.
  #
  # ```
  # File.chown("/foo/bar/baz.cr", 1001, 100)
  # File.chown("/foo/bar", gid: 100)
  # ```
  #
  # Unless *follow_symlinks* is set to `true`, then the owner symlink itself will
  # be changed, otherwise the owner of the symlink destination file will be
  # changed. For example, assuming symlinks as `foo -> bar -> baz`:
  #
  # ```
  # File.chown("foo", gid: 100)                        # changes foo's gid
  # File.chown("foo", gid: 100, follow_symlinks: true) # changes baz's gid
  # ```
  #
  # Use `#chown` if the `File` is already open.
  def self.chown(path : Path | String, uid : Int = -1, gid : Int = -1, follow_symlinks = false) : Nil
    Crystal::System::File.chown(path.to_s, uid, gid, follow_symlinks)
  end

  # Changes the permissions of the specified file.
  #
  # Symlinks are dereferenced, so that only the permissions of the symlink
  # destination are changed, never the permissions of the symlink itself.
  #
  # ```
  # File.chmod("foo", 0o755)
  # File.info("foo").permissions.value # => 0o755
  #
  # File.chmod("foo", 0o700)
  # File.info("foo").permissions.value # => 0o700
  # ```
  #
  # Use `#chmod` if the `File` is already open.
  def self.chmod(path : Path | String, permissions : Int | Permissions) : Nil
    Crystal::System::File.chmod(path.to_s, permissions)
  end

  # Deletes the file at *path*. Raises `File::Error` on failure.
  #
  # On Windows, this also deletes reparse points, including symbolic links,
  # regardless of whether the reparse point is a directory.
  #
  # ```
  # File.write("foo", "")
  # File.delete("./foo")
  # File.delete("./bar") # raises File::NotFoundError (No such file or directory)
  # ```
  def self.delete(path : Path | String) : Nil
    Crystal::System::File.delete(path.to_s, raise_on_missing: true)
  end

  # Deletes the file at *path*, or returns `false` if the file does not exist.
  # Raises `File::Error` on other kinds of failure.
  #
  # On Windows, this also deletes reparse points, including symbolic links,
  # regardless of whether the reparse point is a directory.
  #
  # ```
  # File.write("foo", "")
  # File.delete?("./foo") # => true
  # File.delete?("./bar") # => false
  # ```
  def self.delete?(path : Path | String) : Bool
    Crystal::System::File.delete(path.to_s, raise_on_missing: false)
  end

  # Returns *filename*'s extension, or an empty string if it has no extension.
  #
  # ```
  # File.extname("foo.cr") # => ".cr"
  # ```
  def self.extname(filename : Path | String) : String
    Path.new(filename).extension
  end

  # Converts *path* to an absolute path. Relative paths are
  # referenced from the current working directory of the process unless
  # *dir* is given, in which case it will be used as the starting point.
  # "~" is expanded to the value passed to *home*.
  # If it is `false` (default), home is not expanded.
  # If `true`, it is expanded to the user's home directory (`Path.home`).
  #
  # ```
  # File.expand_path("foo")                 # => "/home/.../foo"
  # File.expand_path("~/foo", home: "/bar") # => "/bar/foo"
  # File.expand_path("baz", "/foo/bar")     # => "/foo/bar/baz"
  # ```
  def self.expand_path(path : Path | String, dir = nil, *, home = false) : String
    Path.new(path).expand(dir || Dir.current, home: home).to_s
  end

  # Resolves the real path of *path* by following symbolic links.
  def self.realpath(path : Path | String) : String
    Crystal::System::File.realpath(path.to_s)
  end

  # :ditto:
  @[Deprecated("Use `.realpath` instead.")]
  def self.real_path(path : Path | String) : String
    realpath(path)
  end

  # Creates a new link (also known as a hard link) at *new_path* to an existing file
  # given by *old_path*.
  def self.link(old_path : Path | String, new_path : Path | String) : Nil
    Crystal::System::File.link(old_path.to_s, new_path.to_s)
  end

  # Creates a symbolic link at *new_path* to an existing file given by *old_path*.
  def self.symlink(old_path : Path | String, new_path : Path | String) : Nil
    Crystal::System::File.symlink(old_path.to_s, new_path.to_s)
  end

  # Returns `true` if the *path* is a symbolic link.
  def self.symlink?(path : Path | String) : Bool
    if info = info?(path, follow_symlinks: false)
      info.type.symlink?
    else
      false
    end
  end

  # Returns the target of a symbolic link.
  def self.readlink(path : Path | String) : String
    Crystal::System::File.readlink(path.to_s) { }
  end

  # Returns the target of a symbolic link.
  #
  # Returns `nil` if *path* does not exist or is not a symbolic link.
  def self.readlink?(path : Path | String) : String?
    Crystal::System::File.readlink(path.to_s) { return nil }
  end

  # Opens the file named by *filename*. If a file is being created, its initial
  # permissions may be set using the *perm* parameter.
  #
  # See `self.new` for what *mode* can be.
  {% begin %}
  def self.open(filename : Path | String, mode = "r", perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated] {% end %} blocking = nil) : self
    new_internal(filename.to_s, mode, perm, encoding, invalid, blocking)
  end
  {% end %}

  # Opens the file named by *filename*. If a file is being created, its initial
  # permissions may be set using the *perm* parameter. Then given block will be passed the opened
  # file as an argument, the file will be automatically closed when the block returns.
  #
  # See `self.new` for what *mode* can be.
  {% begin %}
  def self.open(filename : Path | String, mode = "r", perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated] {% end %} blocking = nil, &)
    open_internal(filename.to_s, mode, perm, encoding, invalid, blocking) { |file| yield file }
  end
  {% end %}

  protected def self.open_internal(filename, mode = "r", perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil, blocking = nil, &)
    file = new_internal(filename, mode, perm, encoding, invalid, blocking)
    begin
      yield file
    ensure
      file.close
    end
  end

  # Returns the content of *filename* as a string.
  #
  # ```
  # File.write("bar", "foo")
  # File.read("bar") # => "foo"
  # ```
  {% begin %}
  def self.read(filename : Path | String, encoding = nil, invalid = nil, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated] {% end %} blocking = nil) : String
    open_internal(filename, "r", blocking: blocking) do |file|
      if encoding
        file.set_encoding(encoding, invalid: invalid)
        file.gets_to_end
      else
        # We try to read a string with an initialize capacity
        # equal to the file's size, but the size might not be
        # correct or even be zero (for example for /proc files)
        size = file.size.to_i
        size = 256 if size == 0
        String.build(size) do |io|
          IO.copy(file, io)
        end
      end
    end
  end
  {% end %}

  # Yields each line in *filename* to the given block.
  #
  # ```
  # File.write("foobar", "foo\nbar")
  #
  # array = [] of String
  # File.each_line("foobar") do |line|
  #   array << line
  # end
  # array # => ["foo", "bar"]
  # ```
  {% begin %}
  def self.each_line(filename : Path | String, encoding = nil, invalid = nil, chomp = true, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated] {% end %} blocking = nil, &)
    open_internal(filename, "r", encoding: encoding, invalid: invalid, blocking: blocking) do |file|
      file.each_line(chomp: chomp) do |line|
        yield line
      end
    end
  end
  {% end %}

  # Returns all lines in *filename* as an array of strings.
  #
  # ```
  # File.write("foobar", "foo\nbar")
  # File.read_lines("foobar") # => ["foo", "bar"]
  # ```
  {% begin %}
  def self.read_lines(filename : Path | String, encoding = nil, invalid = nil, chomp = true, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated] {% end %} blocking = nil) : Array(String)
    lines = [] of String
    open_internal(filename, "r", encoding: encoding, invalid: invalid, blocking: blocking) do |file|
      file.each_line(chomp: chomp) do |line|
        lines << line
      end
    end
    lines
  end
  {% end %}

  # Writes the given *content* to *filename*.
  #
  # By default, an existing file will be overwritten.
  #
  # *filename* will be created if it does not already exist.
  #
  # ```
  # File.write("foo", "bar")
  # File.write("foo", "baz", mode: "a")
  # ```
  #
  # NOTE: If the content is a `Slice(UInt8)`, those bytes will be written.
  # If it's an `IO`, all bytes from the `IO` will be written.
  # Otherwise, the string representation of *content* will be written
  # (the result of invoking `to_s` on *content*).
  #
  # See `self.new` for what *mode* can be.
  {% begin %}
  def self.write(filename : Path | String, content, perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil, mode = "w", {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated] {% end %} blocking = nil)
    open_internal(filename, mode, perm, encoding: encoding, invalid: invalid, blocking: blocking) do |file|
      case content
      when Bytes
        file.sync = true
        file.write(content)
      when IO
        file.sync = true
        IO.copy(content, file)
      else
        file.print(content)
      end
    end
  end
  {% end %}

  # Copies the file *src* to the file *dst*.
  # Permission bits are copied too.
  #
  # ```
  # File.touch("afile")
  # File.chmod("afile", 0o600)
  # File.copy("afile", "afile_copy")
  # File.info("afile_copy").permissions.value # => 0o600
  # ```
  def self.copy(src : String | Path, dst : String | Path) : Nil
    open_internal(src) do |s|
      permissions = s.info.permissions
      open_internal(dst, "wb", perm: permissions) do |d|
        # If permissions don't match, we opened a pre-existing file with
        # different permissions and need to change them explicitly.
        # The permission change does not have any effect on the open file descriptor d.
        if d.info.permissions != permissions
          d.chmod(permissions)
        end

        # TODO use sendfile or copy_file_range syscall. See #8926, #8919
        IO.copy(s, d)
      end
    end
  end

  # Returns a new string formed by joining the strings using `File::SEPARATOR`.
  #
  # ```
  # File.join("foo", "bar", "baz")       # => "foo/bar/baz"
  # File.join("foo/", "/bar/", "/baz")   # => "foo/bar/baz"
  # File.join("/foo/", "/bar/", "/baz/") # => "/foo/bar/baz/"
  # ```
  def self.join(*parts : String | Path) : String
    Path.new(*parts).to_s
  end

  # Returns a new string formed by joining the strings using `File::SEPARATOR`.
  #
  # ```
  # File.join({"foo", "bar", "baz"})       # => "foo/bar/baz"
  # File.join({"foo/", "/bar/", "/baz"})   # => "foo/bar/baz"
  # File.join(["/foo/", "/bar/", "/baz/"]) # => "/foo/bar/baz/"
  # ```
  def self.join(parts : Enumerable) : String
    Path.new(parts).to_s
  end

  # Moves *old_filename* to *new_filename*.
  #
  # ```
  # File.write("afile", "foo")
  # File.exists?("afile") # => true
  #
  # File.rename("afile", "afile.cr")
  # File.exists?("afile")    # => false
  # File.exists?("afile.cr") # => true
  # ```
  def self.rename(old_filename : Path | String, new_filename : Path | String) : Nil
    if error = Crystal::System::File.rename(old_filename.to_s, new_filename.to_s)
      raise error
    end
  end

  # Rename the current `File`
  def rename(new_filename : Path | String) : Nil
    File.rename(@path, new_filename)
    @path = new_filename.to_s
  end

  # Sets the access and modification times of *filename*.
  #
  # Use `#utime` if the `File` is already open.
  def self.utime(atime : Time, mtime : Time, filename : Path | String) : Nil
    Crystal::System::File.utime(atime, mtime, filename.to_s)
  end

  # Attempts to set the access and modification times of the file named
  # in the *filename* parameter to the value given in *time*.
  #
  # If the file does not exist, it will be created.
  #
  # Use `#touch` if the `File` is already open.
  def self.touch(filename : Path | String, time : Time = Time.utc) : Nil
    open_internal(filename, "a") { } unless exists?(filename)
    utime time, time, filename
  end

  # Returns the size in bytes of the currently opened file.
  def size : Int64
    info.size
  end

  # Truncates the file to the specified *size*. Requires that the current file is opened
  # for writing.
  def truncate(size = 0) : Nil
    flush
    system_truncate(size)
  end

  # Yields an `IO` to read a section inside this file.
  # Multiple sections can be read concurrently.
  def read_at(offset, bytesize, & : IO ->)
    self_bytesize = self.size

    unless 0 <= offset <= self_bytesize
      raise ArgumentError.new("Offset out of bounds")
    end

    if bytesize < 0
      raise ArgumentError.new("Negative bytesize")
    end

    unless 0 <= offset + bytesize <= self_bytesize
      raise ArgumentError.new("Bytesize out of bounds")
    end

    io = PReader.new(self, offset, bytesize)
    yield io ensure io.close
  end

  def inspect(io : IO) : Nil
    io << "#<File:" << @path
    io << " (closed)" if closed?
    io << '>'
  end

  # Changes the owner of the specified file.
  #
  # ```
  # file.chown(1001, 100)
  # file.chown(gid: 100)
  # ```
  def chown(uid : Int = -1, gid : Int = -1) : Nil
    Crystal::System::File.fchown(@path, fd, uid, gid)
  end

  # Changes the permissions of the specified file.
  #
  # ```
  # file.chmod(0o755)
  # file.info.permissions.value # => 0o755
  #
  # file.chmod(0o700)
  # file.info.permissions.value # => 0o700
  # ```
  def chmod(permissions : Int | Permissions) : Nil
    system_chmod(@path, permissions)
  end

  # Sets the access and modification times
  def utime(atime : Time, mtime : Time) : Nil
    system_utime(atime, mtime, @path)
  end

  # Attempts to set the access and modification times
  # to the value given in *time*.
  def touch(time : Time = Time.utc) : Nil
    utime time, time
  end

  # Deletes this file.
  def delete : Nil
    File.delete(@path)
  end
end

require "./file/*"
