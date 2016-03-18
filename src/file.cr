lib LibC
  fun access(filename : Char*, how : Int) : Int
  fun link(oldpath : Char*, newpath : Char*) : Int
  fun rename(oldname : Char*, newname : Char*) : Int
  fun symlink(oldpath : Char*, newpath : Char*) : Int
  fun unlink(filename : Char*) : Int
  fun ftruncate(fd : Int, size : OffT) : Int
  fun realpath(filename : Char*, realpath : Char*) : Char*

  F_OK = 0
  X_OK = 1 << 0
  W_OK = 1 << 1
  R_OK = 1 << 2
end

class File < IO::FileDescriptor
  # The file/directory separator character. '/' in unix, '\\' in windows.
  SEPARATOR = ifdef windows
    '\\'
  else
    '/'
  end

  # The file/directory separator string. "/" in unix, "\\" in windows.
  SEPARATOR_STRING = ifdef windows
    "\\"
  else
    "/"
  end

  # :nodoc:
  DEFAULT_CREATE_MODE = LibC::S_IRUSR | LibC::S_IWUSR | LibC::S_IRGRP | LibC::S_IROTH

  def initialize(filename, mode = "r", perm = DEFAULT_CREATE_MODE, encoding = nil, invalid = nil)
    oflag = open_flag(mode) | LibC::O_CLOEXEC

    fd = LibC.open(filename.check_no_null_byte, oflag, perm)
    if fd < 0
      raise Errno.new("Error opening file '#{filename}' with mode '#{mode}'")
    end

    @path = filename
    self.set_encoding(encoding, invalid: invalid) if encoding
    super(fd, blocking: true)
  end

  protected def open_flag(mode)
    if mode.size == 0
      raise "invalid access mode #{mode}"
    end

    m = 0
    o = 0
    case mode[0]
    when 'r'
      m = LibC::O_RDONLY
    when 'w'
      m = LibC::O_WRONLY
      o = LibC::O_CREAT | LibC::O_TRUNC
    when 'a'
      m = LibC::O_WRONLY
      o = LibC::O_CREAT | LibC::O_APPEND
    else
      raise "invalid access mode #{mode}"
    end

    case mode.size
    when 1
      # Nothing
    when 2
      case mode[1]
      when '+'
        m = LibC::O_RDWR
      when 'b'
        # Nothing
      else
        raise "invalid access mode #{mode}"
      end
    else
      raise "invalid access mode #{mode}"
    end

    oflag = m | o
  end

  getter path : String

  # Returns a `File::Stat` object for the named file or raises
  # `Errno` in case of an error. In case of a symbolic link
  # it is followed and information about the target is returned.
  #
  # ```
  # echo "foo" > foo
  # File.stat("foo").size  # => 4
  # File.stat("foo").mtime # => 2015-09-23 06:24:19 UTC
  # ```
  def self.stat(path)
    if LibC.stat(path.check_no_null_byte, out stat) != 0
      raise Errno.new("Unable to get stat for '#{path}'")
    end
    Stat.new(stat)
  end

  # Returns a `File::Stat` object for the named file or raises
  # `Errno` in case of an error. In case of a symbolic link
  # information about it is returned.
  #
  # ```
  # echo "foo" > foo
  # File.lstat("foo").size  # => 4
  # File.lstat("foo").mtime # => 2015-09-23 06:24:19 UTC
  # ```
  def self.lstat(path)
    if LibC.lstat(path.check_no_null_byte, out stat) != 0
      raise Errno.new("Unable to get lstat for '#{path}'")
    end
    Stat.new(stat)
  end

  # Returns true if file exists else returns false
  #
  # ```
  # File.exists?("foo") # => false
  # echo "foo" > foo
  # File.exists?("foo") # => true
  # ```
  def self.exists?(filename)
    accessible?(filename, LibC::F_OK)
  end

  # Returns true if file is readable by the real user id of this process else returns false
  #
  # ```
  # echo "foo" > foo
  # File.readable?("foo") # => true
  # ```
  def self.readable?(filename)
    accessible?(filename, LibC::R_OK)
  end

  # Returns true if file is writable by the real user id of this process else returns false
  #
  # ```
  # echo "foo" > foo
  # File.writable?("foo") # => true
  # ```
  def self.writable?(filename)
    accessible?(filename, LibC::W_OK)
  end

  # Returns true if file is executable by the real user id of this process else returns false
  #
  # ```
  # echo "foo" > foo
  # File.executable?("foo") # => false
  # ```
  def self.executable?(filename)
    accessible?(filename, LibC::X_OK)
  end

  # Convenience method to avoid code on LibC.access calls. Not meant to be called by users of this class.
  private def self.accessible?(filename, flag)
    LibC.access(filename.check_no_null_byte, flag) == 0
  end

  # Returns true if given path exists and is a file
  #
  # ```crystal
  # # touch foo
  # # mkdir bar
  # File.file?("foo")    # => true
  # File.file?("bar")    # => false
  # File.file?("foobar") # => false
  # ```
  def self.file?(path)
    if LibC.stat(path.check_no_null_byte, out stat) != 0
      if Errno.value == Errno::ENOENT
        return false
      else
        raise Errno.new("stat")
      end
    end
    File::Stat.new(stat).file?
  end

  # Returns true if the given path exists and is a directory
  #
  # ```crystal
  # # touch foo
  # # mkdir bar
  # File.directory?("foo")    # => false
  # File.directory?("bar")    # => true
  # File.directory?("foobar") # => false
  # ```
  def self.directory?(path)
    Dir.exists?(path)
  end

  # Returns all components of the given filename except the last one
  #
  # ```
  # File.dirname("/foo/bar/file.cr") # => "/foo/bar"
  # ```
  def self.dirname(filename)
    filename.check_no_null_byte
    index = filename.rindex SEPARATOR
    if index
      if index == 0
        SEPARATOR_STRING
      else
        filename[0, index]
      end
    else
      "."
    end
  end

  # Returns the last component of the given filename
  #
  # ```
  # File.basename("/foo/bar/file.cr") # => "file.cr"
  # ```
  def self.basename(filename)
    return "" if filename.bytesize == 0
    return SEPARATOR_STRING if filename == SEPARATOR_STRING

    filename.check_no_null_byte

    last = filename.size - 1
    last -= 1 if filename[last] == SEPARATOR

    index = filename.rindex SEPARATOR, last
    if index
      filename[index + 1, last - index]
    else
      filename
    end
  end

  # Returns the last component of the given filename
  # If the given suffix is present at the end of filename, it is removed
  #
  # ```
  # File.basename("/foo/bar/file.cr", ".cr") # => "file"
  # ```
  def self.basename(filename, suffix)
    suffix.check_no_null_byte
    basename = basename(filename)
    basename = basename[0, basename.size - suffix.size] if basename.ends_with?(suffix)
    basename
  end

  # Delete a file. Deleting non-existent file will raise an exception.
  #
  # ```crystal
  # # touch foo
  # File.delete("./foo")
  # # => nil
  # File.delete("./bar")
  # # => Error deleting file './bar': No such file or directory (Errno)
  # ```
  def self.delete(filename)
    err = LibC.unlink(filename.check_no_null_byte)
    if err == -1
      raise Errno.new("Error deleting file '#{filename}'")
    end
  end

  # Returns a file's extension, or an empty string if the file has no extension.
  #
  # ```crystal
  # File.extname("foo.cr")
  # # => .cr
  # ```
  def self.extname(filename)
    filename.check_no_null_byte

    dot_index = filename.rindex('.')

    if dot_index && dot_index != filename.size - 1 && filename[dot_index - 1] != SEPARATOR
      filename[dot_index, filename.size - dot_index]
    else
      ""
    end
  end

  def self.expand_path(path, dir = nil)
    path.check_no_null_byte

    if path.starts_with?('~')
      home = ENV["HOME"]
      if path.size >= 2 && path[1] == SEPARATOR
        path = home + path[1..-1]
      elsif path.size < 2
        return home
      end
    end

    unless path.starts_with?(SEPARATOR)
      dir = dir ? expand_path(dir) : Dir.current
      path = "#{dir}#{SEPARATOR}#{path}"
    end

    parts = path.split(SEPARATOR)
    items = [] of String
    parts.each do |part|
      case part
      when "", "."
        # Nothing
      when ".."
        items.pop?
      else
        items << part
      end
    end

    String.build do |str|
      ifdef !windows
        str << SEPARATOR_STRING
      end
      items.join SEPARATOR_STRING, str
    end
  end

  # Resolves the real path of the file by following symbolic links
  def self.real_path(path)
    real_path_ptr = LibC.realpath(path, nil)
    raise Errno.new("Error resolving real path of #{path}") unless real_path_ptr
    String.new(real_path_ptr).tap { LibC.free(real_path_ptr as Void*) }
  end

  # Creates a new link (also known as a hard link) to an existing file.
  def self.link(old_path, new_path)
    ret = LibC.symlink(old_path.check_no_null_byte, new_path.check_no_null_byte)
    raise Errno.new("Error creating link from #{old_path} to #{new_path}") if ret != 0
    ret
  end

  # Creates a symbolic link to an existing file.
  def self.symlink(old_path, new_path)
    ret = LibC.symlink(old_path.check_no_null_byte, new_path.check_no_null_byte)
    raise Errno.new("Error creating symlink from #{old_path} to #{new_path}") if ret != 0
    ret
  end

  # Returns true if the pointed file is a symlink.
  def self.symlink?(filename)
    if LibC.lstat(filename.check_no_null_byte, out stat) != 0
      if Errno.value == Errno::ENOENT
        return false
      else
        raise Errno.new("stat")
      end
    end
    (stat.st_mode & LibC::S_IFMT) == LibC::S_IFLNK
  end

  def self.open(filename, mode = "r", perm = DEFAULT_CREATE_MODE, encoding = nil, invalid = nil)
    new filename, mode, perm, encoding, invalid
  end

  def self.open(filename, mode = "r", perm = DEFAULT_CREATE_MODE, encoding = nil, invalid = nil)
    file = File.new filename, mode, perm, encoding, invalid
    begin
      yield file
    ensure
      file.close
    end
  end

  # Returns the content of the given file as a string.
  #
  # ```crystal
  # # echo "foo" >> bar
  # File.read("./bar")
  # # => foo
  # ```
  def self.read(filename, encoding = nil, invalid = nil)
    File.open(filename, "r") do |file|
      if encoding
        file.set_encoding(encoding, invalid: invalid)
        file.gets_to_end
      else
        size = file.size.to_i
        String.new(size) do |buffer|
          file.read Slice.new(buffer, size)
          {size.to_i, 0}
        end
      end
    end
  end

  # Yields each line of the given file to the given block.
  #
  # ```crystal
  # File.each_line("./foo") do |line|
  #   # loop
  # end
  # ```
  def self.each_line(filename, encoding = nil, invalid = nil)
    File.open(filename, "r", encoding: encoding, invalid: invalid) do |file|
      file.each_line do |line|
        yield line
      end
    end
  end

  # Returns all lines of the given file as an array of strings.
  #
  # ```crystal
  # # echo "foo" >> foobar
  # # echo "bar" >> foobar
  # File.read_lines("./foobar")
  # # => ["foo\n","bar\n"]
  # ```
  def self.read_lines(filename, encoding = nil, invalid = nil)
    lines = [] of String
    each_line(filename, encoding: encoding, invalid: invalid) do |line|
      lines << line
    end
    lines
  end

  # Write the given content to the given filename.
  # An existing file will be overwritten, or a file will be created with the given filename.
  #
  # ```crystal
  # File.write("./foo", "bar")
  # ```
  def self.write(filename, content, perm = DEFAULT_CREATE_MODE, encoding = nil, invalid = nil)
    File.open(filename, "w", perm, encoding: encoding, invalid: invalid) do |file|
      file.print(content)
    end
  end

  # Returns a new string formed by joining the strings using File::SEPARATOR.
  #
  # ```
  # File.join("foo", "bar", "baz")       # => "foo/bar/baz"
  # File.join("foo/", "/bar/", "/baz")   # => "foo/bar/baz"
  # File.join("/foo/", "/bar/", "/baz/") # => "/foo/bar/baz/"
  # ```
  def self.join(*parts)
    join parts
  end

  # Returns a new string formed by joining the strings using File::SEPARATOR.
  #
  # ```
  # File.join("foo", "bar", "baz")       # => "foo/bar/baz"
  # File.join("foo/", "/bar/", "/baz")   # => "foo/bar/baz"
  # File.join("/foo/", "/bar/", "/baz/") # => "/foo/bar/baz/"
  # ```
  def self.join(parts : Array | Tuple)
    String.build do |str|
      parts.each_with_index do |part, index|
        part.check_no_null_byte

        str << SEPARATOR if index > 0

        byte_start = 0
        byte_count = part.bytesize

        if index > 0 && part.starts_with?(SEPARATOR)
          byte_start += 1
          byte_count -= 1
        end

        if index != parts.size - 1 && part.ends_with?(SEPARATOR)
          byte_count -= 1
        end

        str.write part.unsafe_byte_slice(byte_start, byte_count)
      end
    end
  end

  # Returns the size of the given file in bytes.
  def self.size(filename)
    stat(filename.check_no_null_byte).size
  end

  def self.rename(old_filename, new_filename)
    code = LibC.rename(old_filename.check_no_null_byte, new_filename.check_no_null_byte)
    if code != 0
      raise Errno.new("Error renaming file '#{old_filename}' to '#{new_filename}'")
    end
    code
  end

  def size
    stat.size
  end

  # Truncates the file to the specified size. Requires a write file descriptor
  def truncate(size = 0)
    flush
    code = LibC.ftruncate(fd, size)
    if code != 0
      raise Errno.new("Error truncating file '#{path}'")
    end
    code
  end

  def to_s(io)
    io << "#<File:" << @path
    io << " (closed)" if closed?
    io << ">"
    io
  end
end

require "file/*"
