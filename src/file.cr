lib LibC
  fun access(filename : Char*, how : Int) : Int
  fun link(oldpath : Char*, newpath : Char*) : Int
  fun rename(oldname : Char*, newname : Char*) : Int
  fun symlink(oldpath : Char*, newpath : Char*) : Int
  fun unlink(filename : Char*) : Int
  fun ftruncate(fd : Int, size : OffT) : Int

  F_OK = 0
  X_OK = 1 << 0
  W_OK = 1 << 1
  R_OK = 1 << 2
end

class File < IO::FileDescriptor
  # The file/directory separator character. '/' in unix, '\\' in windows.
  SEPARATOR = ifdef windows; '\\'; else; '/'; end

  # The file/directory separator string. "/" in unix, "\\" in windows.
  SEPARATOR_STRING = ifdef windows; "\\"; else; "/"; end

  # :nodoc:
  DEFAULT_CREATE_MODE = LibC::S_IRUSR | LibC::S_IWUSR | LibC::S_IRGRP | LibC::S_IROTH

  def initialize(filename, mode = "r", perm = DEFAULT_CREATE_MODE)
    oflag = open_flag(mode) | LibC::O_CLOEXEC

    fd = LibC.open(filename, oflag, perm)
    if fd < 0
      raise Errno.new("Error opening file '#{filename}' with mode '#{mode}'")
    end

    @path = filename
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

  getter path

  # Seeks to a given *offset* (in bytes) according to the *whence* argument.
  #
  # ```
  # file = File.new("testfile")
  # file.gets(3) #=> "abc"
  # file.seek(1, IO::Seek::Set)
  # file.gets(2) #=> "bc"
  # file.seek(-1, IO::Seek::Current)
  # file.gets(1) #=> "c"
  # ```
  def seek(offset, whence = Seek::Set : Seek)
    check_open

    flush
    seek_value = LibC.lseek(@fd, offset, whence)
    if seek_value == -1
      raise Errno.new "Unable to seek"
    end

    @in_buffer_rem = Slice.new(Pointer(UInt8).null, 0)
  end

  # Same as `pos`.
  def tell
    pos
  end

  # Returns the current position (in bytes) in this File.
  #
  # ```
  # io = StringIO.new "hello"
  # io.pos     #=> 0
  # io.gets(2) #=> "he"
  # io.pos     #=> 2
  # ```
  def pos
    check_open

    seek_value = LibC.lseek(@fd, 0, Seek::Current)
    raise Errno.new "Unable to tell" if seek_value == -1

    seek_value - @in_buffer_rem.size
  end

  # Sets the current position (in bytes) in this File.
  #
  # ```
  # io = StringIO.new "hello"
  # io.pos = 3
  # io.gets_to_end #=> "lo"
  # ```
  def pos=(value)
    seek value
  end

  # Returns a `File::Stat` object for the named file or raises
  # `Errno` in case of an error. In case of a symbolic link
  # it is followed and information about the target is returned.
  #
  # ```
  # echo "foo" > foo
  # File.stat("foo").size    #=> 4
  # File.stat("foo").mtime   #=> 2015-09-23 06:24:19 UTC
  # ```
  def self.stat(path)
    if LibC.stat(path, out stat) != 0
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
  # File.lstat("foo").size    #=> 4
  # File.lstat("foo").mtime   #=> 2015-09-23 06:24:19 UTC
  # ```
  def self.lstat(path)
    if LibC.lstat(path, out stat) != 0
      raise Errno.new("Unable to get lstat for '#{path}'")
    end
    Stat.new(stat)
  end

  # Returns true if file exists else returns false
  #
  # ```
  # File.exists?("foo")    #=> false
  # echo "foo" > foo
  # File.exists?("foo")    #=> true
  # ```
  def self.exists?(filename)
    LibC.access(filename, LibC::F_OK) == 0
  end

  # Returns true if given path exists and is a file
  # 
  # ```crystal
  # # touch foo
  # # mkdir bar
  # File.file?("foo")    #=> true
  # File.file?("bar")    #=> false
  # File.file?("foobar") #=> false
  # ```
  def self.file?(path)
    if LibC.stat(path, out stat) != 0
      if LibC.errno == Errno::ENOENT
        return false
      else
        raise Errno.new("stat")
      end
    end
    File::Stat.new(stat).file?
  end

  # Returns true if given path exists and is a directory
  # 
  # ```crystal
  # # touch foo
  # # mkdir bar
  # File.directory?("foo")    #=> false
  # File.directory?("bar")    #=> true
  # File.directory?("foobar") #=> false
  # ```
  def self.directory?(path)
    Dir.exists?(path)
  end

  def self.dirname(filename)
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

  def self.basename(filename)
    return "" if filename.bytesize == 0

    last = filename.size - 1
    last -= 1 if filename[last] == SEPARATOR

    index = filename.rindex SEPARATOR, last
    if index
      filename[index + 1, last - index]
    else
      filename
    end
  end

  def self.basename(filename, suffix)
    basename = basename(filename)
    basename = basename[0, basename.size - suffix.size] if basename.ends_with?(suffix)
    basename
  end

  # Delete a file. Deleting non-existent file will raise an exception.
  #
  # ```crystal
  # # touch foo
  # File.delete("./foo")
  # #=> nil
  # File.delete("./bar")
  # #=> Error deleting file './bar': No such file or directory (Errno)
  # ```
  def self.delete(filename)
    err = LibC.unlink(filename)
    if err == -1
      raise Errno.new("Error deleting file '#{filename}'")
    end
  end

  # Returns a file's extension, or an empty string if the file has no extension.
  # 
  # ```crystal
  # File.extname("foo.cr")
  # #=> .cr
  # ```
  def self.extname(filename)
    dot_index = filename.rindex('.')

    if dot_index && dot_index != filename.size - 1  && filename[dot_index - 1] != SEPARATOR
      filename[dot_index, filename.size - dot_index]
    else
      ""
    end
  end

  def self.expand_path(path, dir = nil)
    if path.starts_with?('~')
      home = ENV["HOME"]
      if path.size >= 2 && path[1] == SEPARATOR
        path = home + path[1..-1]
      elsif path.size < 2
        return home
      end
    end

    unless path.starts_with?(SEPARATOR)
      dir = dir ? expand_path(dir) : Dir.working_directory
      path = "#{dir}#{SEPARATOR}#{path}"
    end

    parts = path.split(SEPARATOR)
    was_letter = false
    first_slash = true
    items = [] of String
    parts.each do |part|
      if part.empty? && !was_letter
        items << part if !first_slash
      elsif part == ".."
        items.pop if items.size > 0
      elsif !part.empty? && part != "."
        was_letter = true
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

  # Creates a new link (also known as a hard link) to an existing file.
  def self.link(old_path, new_path)
    ret = LibC.symlink(old_path, new_path)
    raise Errno.new("Error creating link from #{old_path} to #{new_path}") if ret != 0
    ret
  end

  # Creates a symbolic link to an existing file.
  def self.symlink(old_path, new_path)
    ret = LibC.symlink(old_path, new_path)
    raise Errno.new("Error creating symlink from #{old_path} to #{new_path}") if ret != 0
    ret
  end

  # Returns true if the pointed file is a symlink.
  def self.symlink?(filename)
    if LibC.lstat(filename, out stat) != 0
      if LibC.errno == Errno::ENOENT
        return false
      else
        raise Errno.new("stat")
      end
    end
    (stat.st_mode & LibC::S_IFMT) == LibC::S_IFLNK
  end

  def self.open(filename, mode = "r", perm = DEFAULT_CREATE_MODE)
    new filename, mode, perm
  end

  def self.open(filename, mode = "r", perm = DEFAULT_CREATE_MODE)
    file = File.new filename, mode, perm
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
  # #=> foo
  # ```
  def self.read(filename)
    File.open(filename, "r") do |file|
      size = file.size.to_i
      String.new(size) do |buffer|
        file.read Slice.new(buffer, size)
        {size.to_i, 0}
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
  def self.each_line(filename)
    File.open(filename, "r") do |file|
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
  # #=> ["foo\n","bar\n"]
  # ```
  def self.read_lines(filename)
    lines = [] of String
    each_line(filename) do |line|
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
  def self.write(filename, content, perm = DEFAULT_CREATE_MODE)
    File.open(filename, "w", perm) do |file|
      file.print(content)
    end
  end

  # Returns a new string formed by joining the strings using File::SEPARATOR.
  #
  # ```
  # File.join("foo", "bar", "baz") #=> "foo/bar/baz"
  # File.join("foo/", "/bar/", "/baz") #=> "foo/bar/baz"
  # File.join("/foo/", "/bar/", "/baz/") #=> "/foo/bar/baz/"
  # ```
  def self.join(*parts)
    join parts
  end

  # Returns a new string formed by joining the strings using File::SEPARATOR.
  #
  # ```
  # File.join("foo", "bar", "baz") #=> "foo/bar/baz"
  # File.join("foo/", "/bar/", "/baz") #=> "foo/bar/baz"
  # File.join("/foo/", "/bar/", "/baz/") #=> "/foo/bar/baz/"
  # ```
  def self.join(parts : Array | Tuple)
    String.build do |str|
      parts.each_with_index do |part, index|
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
    stat(filename).size
  end

  def self.rename(old_filename, new_filename)
    code = LibC.rename(old_filename, new_filename)
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
