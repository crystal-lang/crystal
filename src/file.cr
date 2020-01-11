require "crystal/system/file"

# A `File` instance represents a file entry in the local file system and allows using it as an `IO`.
#
# ```
# file = File.new("path/to/file")
# content = file.gets_to_end
# file.close
#
# # Implicit close with `open`
# content = File.open("path/to/file") do |file|
#   file.gets_to_end
# end
#
# # Shortcut:
# content = File.read("path/to/file")
# ```
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

  include Crystal::System::File

  # This constructor is provided for subclasses to be able to initialize an
  # `IO::FileDescriptor` with a *path* and *fd*.
  private def initialize(@path, fd, blocking = false, encoding = nil, invalid = nil)
    self.set_encoding(encoding, invalid: invalid) if encoding
    super(fd, blocking)
  end

  # Opens the file named by *filename*.
  #
  # *mode* must be one of the following file open modes:
  #
  # ```text
  # Mode | Description
  # -----+------------------------------------------------------
  # r    | Read-only, starts at the beginning of the file.
  # r+   | Read-write, starts at the beginning of the file.
  # w    | Write-only, truncates existing file to zero length or
  #      | creates a new file if the file doesn't exist.
  # w+   | Read-write, truncates existing file to zero length or
  #      | creates a new file if the file doesn't exist.
  # a    | Write-only, starts at the end of the file,
  #      | creates a new file if the file doesn't exist.
  # a+   | Read-write, starts at the end of the file,
  #      | creates a new file if the file doesn't exist.
  # rb   | Same as 'r' but in binary file mode.
  # wb   | Same as 'w' but in binary file mode.
  # ab   | Same as 'a' but in binary file mode.
  # ```
  #
  # In binary file mode, line endings are not converted to CRLF on Windows.
  def self.new(filename : Path | String, mode = "r", perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil)
    filename = filename.to_s
    fd = Crystal::System::File.open(filename, mode, perm)
    new(filename, fd, blocking: true, encoding: encoding, invalid: invalid)
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
  def self.info?(path : Path | String, follow_symlinks = true) : Info?
    Crystal::System::File.info?(path.to_s, follow_symlinks)
  end

  # Returns a `File::Info` object for the file given by *path* or raises
  # `Errno` in case of an error.
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
  def self.info(path : Path | String, follow_symlinks = true) : Info
    info?(path, follow_symlinks) || raise Errno.new("Unable to get info for '#{path.to_s.inspect_unquoted}''")
  end

  # Returns `true` if *path* exists else returns `false`
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
  def self.same?(path1 : String, path2 : String, follow_symlinks = false) : Bool
    info(path1, follow_symlinks).same_file? info(path2, follow_symlinks)
  end

  # Returns the size of the file at *filename* in bytes.
  # Raises `Errno` if the file at *filename* does not exist.
  #
  # ```
  # File.size("foo") # raises Errno
  # File.write("foo", "foo")
  # File.size("foo") # => 3
  # ```
  def self.size(filename : Path | String) : UInt64
    info(filename).size
  rescue ex : Errno
    raise Errno.new("Error determining size of '#{filename.to_s.inspect_unquoted}'", ex.errno)
  end

  # Returns `true` if the file at *path* is empty, otherwise returns `false`.
  # Raises `Errno` if the file at *path* does not exist.
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
  def self.readable?(path : Path | String) : Bool
    Crystal::System::File.readable?(path.to_s)
  end

  # Returns `true` if *path* is writable by the real user id of this process else returns `false`.
  #
  # ```
  # File.write("foo", "foo")
  # File.writable?("foo") # => true
  # ```
  def self.writable?(path : Path | String) : Bool
    Crystal::System::File.writable?(path.to_s)
  end

  # Returns `true` if *path* is executable by the real user id of this process else returns `false`.
  #
  # ```
  # File.write("foo", "foo")
  # File.executable?("foo") # => false
  # ```
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
  def self.dirname(path) : String
    Path.new(path).dirname
  end

  # Returns the last component of the given *path*.
  #
  # ```
  # File.basename("/foo/bar/file.cr") # => "file.cr"
  # ```
  def self.basename(path) : String
    Path.new(path).basename
  end

  # Returns the last component of the given *path*.
  #
  # If *suffix* is present at the end of *path*, it is removed.
  #
  # ```
  # File.basename("/foo/bar/file.cr", ".cr") # => "file"
  # ```
  def self.basename(path, suffix) : String
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
  def self.chown(path : Path | String, uid : Int = -1, gid : Int = -1, follow_symlinks = false)
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
  def self.chmod(path : Path | String, permissions : Int | Permissions)
    Crystal::System::File.chmod(path.to_s, permissions)
  end

  # Deletes the file at *path*. Deleting non-existent file will raise an exception.
  #
  # ```
  # File.write("foo", "")
  # File.delete("./foo")
  # File.delete("./bar") # raises Errno (No such file or directory)
  # ```
  def self.delete(path : Path | String)
    Crystal::System::File.delete(path.to_s)
  end

  # Returns *filename*'s extension, or an empty string if it has no extension.
  #
  # ```
  # File.extname("foo.cr") # => ".cr"
  # ```
  def self.extname(filename) : String
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
  def self.expand_path(path, dir = nil, *, home = false) : String
    Path.new(path).expand(dir || Dir.current, home: home).to_s
  end

  class BadPatternError < Exception
  end

  # Matches *path* against *pattern*.
  #
  # The pattern syntax is similar to shell filename globbing. It may contain the following metacharacters:
  #
  # * `*` matches an unlimited number of arbitrary characters excluding `/`.
  #   * `"*"` matches all regular files.
  #   * `"c*"` matches all files beginning with `c`.
  #   * `"*c"` matches all files ending with `c`.
  #   * `"*c*"` matches all files that have `c` in them (including at the beginning or end).
  # * `**` matches an unlimited number of arbitrary characters including `/`.
  # * `?` matches any one character excluding `/`.
  # * character sets:
  #   * `[abc]` matches any one of these character.
  #   * `[^abc]` matches any one character other than these.
  #   * `[a-z]` matches any one character in the range.
  # * `{a,b}` matches subpattern `a` or `b`.
  # * `\\` escapes the next character.
  #
  # NOTE: Only `/` is recognized as path separator in both *pattern* and *path*.
  def self.match?(pattern : String, path : Path | String)
    expanded_patterns = [] of String
    File.expand_brace_pattern(pattern, expanded_patterns)

    expanded_patterns.each do |expanded_pattern|
      return true if match_single_pattern(expanded_pattern, path)
    end
    false
  end

  private def self.match_single_pattern(pattern : String, path : String)
    # linear-time algorithm adapted from https://research.swtch.com/glob
    preader = Char::Reader.new(pattern)
    sreader = Char::Reader.new(path)
    next_ppos = 0
    next_spos = 0
    strlen = path.bytesize
    escaped = false

    while true
      pnext = preader.has_next?
      snext = sreader.has_next?

      return true unless pnext || snext

      if pnext
        pchar = preader.current_char
        char = sreader.current_char

        case {pchar, escaped}
        when {'\\', false}
          escaped = true
          preader.next_char
          next
        when {'?', false}
          if snext && char != '/'
            preader.next_char
            sreader.next_char
            next
          end
        when {'*', false}
          double_star = preader.peek_next_char == '*'
          if char == '/' && !double_star
            preader.next_char
            next_spos = 0
            next
          else
            next_ppos = preader.pos
            next_spos = sreader.pos + sreader.current_char_width
            preader.next_char
            preader.next_char if double_star
            next
          end
        when {'[', false}
          pnext = preader.has_next?

          character_matched = false
          character_set_open = true
          escaped = false
          inverted = false
          case preader.peek_next_char
          when '^'
            inverted = true
            preader.next_char
          when ']'
            raise BadPatternError.new "Invalid character set: empty character set"
          end

          while pnext
            pchar = preader.next_char
            case {pchar, escaped}
            when {'\\', false}
              escaped = true
            when {']', false}
              character_set_open = false
              break
            when {'-', false}
              raise BadPatternError.new "Invalid character set: missing range start"
            else
              escaped = false
              if preader.has_next? && preader.peek_next_char == '-'
                preader.next_char
                range_end = preader.next_char
                case range_end
                when ']'
                  raise BadPatternError.new "Invalid character set: missing range end"
                when '\\'
                  range_end = preader.next_char
                end
                range = (pchar..range_end)
                character_matched = true if range.includes?(char)
              elsif char == pchar
                character_matched = true
              end
            end
            pnext = preader.has_next?
            false
          end
          raise BadPatternError.new "Invalid character set: unterminated character set" if character_set_open

          if character_matched != inverted && snext
            preader.next_char
            sreader.next_char
            next
          end
        else
          escaped = false

          if snext && sreader.current_char == pchar
            preader.next_char
            sreader.next_char
            next
          end
        end
      end

      if 0 < next_spos <= strlen
        preader.pos = next_ppos
        sreader.pos = next_spos
        next
      end

      raise BadPatternError.new "Empty escape character" if escaped

      return false
    end
  end

  # :nodoc:
  def self.expand_brace_pattern(pattern : String, expanded)
    reader = Char::Reader.new(pattern)

    lbrace = nil
    rbrace = nil
    alt_start = nil

    alternatives = [] of String

    nest = 0
    escaped = false
    reader.each do |char|
      case {char, escaped}
      when {'{', false}
        lbrace = reader.pos if nest == 0
        nest += 1
      when {'}', false}
        nest -= 1

        if nest == 0
          rbrace = reader.pos
          start = (alt_start || lbrace).not_nil! + 1
          alternatives << pattern.byte_slice(start, reader.pos - start)
          break
        end
      when {',', false}
        if nest == 1
          start = (alt_start || lbrace).not_nil! + 1
          alternatives << pattern.byte_slice(start, reader.pos - start)
          alt_start = reader.pos
        end
      when {'\\', false}
        escaped = true
      else
        escaped = false
      end
    end

    if lbrace && rbrace
      front = pattern.byte_slice(0, lbrace)
      back = pattern.byte_slice(rbrace + 1)

      alternatives.each do |alt|
        brace_pattern = {front, alt, back}.join

        expand_brace_pattern brace_pattern, expanded
      end
    else
      expanded << pattern
    end
  end

  # Resolves the real path of *path* by following symbolic links.
  def self.real_path(path) : String
    Crystal::System::File.real_path(path)
  end

  # Creates a new link (also known as a hard link) at *new_path* to an existing file
  # given by *old_path*.
  def self.link(old_path, new_path)
    Crystal::System::File.link(old_path, new_path)
  end

  # Creates a symbolic link at *new_path* to an existing file given by *old_path*.
  def self.symlink(old_path, new_path)
    Crystal::System::File.symlink(old_path, new_path)
  end

  # Returns `true` if the *path* is a symbolic link.
  def self.symlink?(path) : Bool
    if info = info?(path, follow_symlinks: false)
      info.type.symlink?
    else
      false
    end
  end

  # Returns value of a symbolic link .
  def self.readlink(path) : String
    Crystal::System::File.readlink(path)
  end

  # Opens the file named by *filename*. If a file is being created, its initial
  # permissions may be set using the *perm* parameter.
  #
  # See `self.new` for what *mode* can be.
  def self.open(filename : Path | String, mode = "r", perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil) : self
    new filename, mode, perm, encoding, invalid
  end

  # Opens the file named by *filename*. If a file is being created, its initial
  # permissions may be set using the *perm* parameter. Then given block will be passed the opened
  # file as an argument, the file will be automatically closed when the block returns.
  #
  # See `self.new` for what *mode* can be.
  def self.open(filename : Path | String, mode = "r", perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil)
    file = new filename, mode, perm, encoding, invalid
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
  def self.read(filename, encoding = nil, invalid = nil) : String
    open(filename, "r") do |file|
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
  def self.each_line(filename, encoding = nil, invalid = nil, chomp = true)
    open(filename, "r", encoding: encoding, invalid: invalid) do |file|
      file.each_line(chomp: chomp) do |line|
        yield line
      end
    end
  end

  # Returns all lines in *filename* as an array of strings.
  #
  # ```
  # File.write("foobar", "foo\nbar")
  # File.read_lines("foobar") # => ["foo", "bar"]
  # ```
  def self.read_lines(filename, encoding = nil, invalid = nil, chomp = true) : Array(String)
    lines = [] of String
    each_line(filename, encoding: encoding, invalid: invalid, chomp: chomp) do |line|
      lines << line
    end
    lines
  end

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
  def self.write(filename, content, perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil, mode = "w")
    open(filename, mode, perm, encoding: encoding, invalid: invalid) do |file|
      case content
      when Bytes
        file.write(content)
      when IO
        IO.copy(content, file)
      else
        file.print(content)
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
  def self.join(parts : Array | Tuple) : String
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
  def self.rename(old_filename, new_filename) : Nil
    Crystal::System::File.rename(old_filename, new_filename)
  end

  # Sets the access and modification times of *filename*.
  def self.utime(atime : Time, mtime : Time, filename : String) : Nil
    Crystal::System::File.utime(atime, mtime, filename)
  end

  # Attempts to set the access and modification times of the file named
  # in the *filename* parameter to the value given in *time*.
  #
  # If the file does not exist, it will be created.
  def self.touch(filename : String, time : Time = Time.utc)
    open(filename, "a") { } unless exists?(filename)
    utime time, time, filename
  end

  # Returns the size in bytes of the currently opened file.
  def size
    info.size
  end

  # Truncates the file to the specified *size*. Requires that the current file is opened
  # for writing.
  def truncate(size = 0) : Nil
    flush
    system_truncate(size)
  end

  # Flushes all data written to this File to the disk device so that
  # all changed information can be retrieved even if the system
  # crashes or is rebooted. The call blocks until the device reports that
  # the transfer has completed.
  # To reduce disk activity the *flush_metadata* parameter can be set to false,
  # then the syscall *fdatasync* will be used and only data required for
  # subsequent data retrieval is flushed. Metadata such as modified time and
  # access time is not written.
  def fsync(flush_metadata = true) : Nil
    flush
    system_fsync(flush_metadata)
  end

  # Yields an `IO` to read a section inside this file.
  # Multiple sections can be read concurrently.
  def read_at(offset, bytesize, &block)
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

    io = PReader.new(fd, offset, bytesize)
    yield io ensure io.close
  end

  def inspect(io : IO) : Nil
    io << "#<File:" << @path
    io << " (closed)" if closed?
    io << '>'
  end

  # TODO: use fcntl/lockf instead of flock (which doesn't lock over NFS)
  # TODO: always use non-blocking locks, yield fiber until resource becomes available

  def flock_shared(blocking = true)
    flock_shared blocking
    begin
      yield
    ensure
      flock_unlock
    end
  end

  # Places a shared advisory lock. More than one process may hold a shared lock for a given file at a given time.
  # `Errno::EWOULDBLOCK` is raised if *blocking* is set to `false` and an existing exclusive lock is set.
  def flock_shared(blocking = true)
    system_flock_shared(blocking)
  end

  def flock_exclusive(blocking = true)
    flock_exclusive blocking
    begin
      yield
    ensure
      flock_unlock
    end
  end

  # Places an exclusive advisory lock. Only one process may hold an exclusive lock for a given file at a given time.
  # `Errno::EWOULDBLOCK` is raised if *blocking* is set to `false` and any existing lock is set.
  def flock_exclusive(blocking = true)
    system_flock_exclusive(blocking)
  end

  # Removes an existing advisory lock held by this process.
  def flock_unlock
    system_flock_unlock
  end

  # Deletes this file.
  def delete
    File.delete(@path)
  end
end

require "./file/*"
