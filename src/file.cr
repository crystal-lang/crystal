lib LibC
  fun access(filename : UInt8*, how : Int32) : Int32
  fun link(oldpath : UInt8*, newpath : UInt8*) : Int32
  fun rename(oldname : UInt8*, newname : UInt8*) : Int32
  fun symlink(oldpath : UInt8*, newpath : UInt8*) : Int32
  fun unlink(filename : UInt8*) : Int32

  F_OK = 0
  X_OK = 1 << 0
  W_OK = 1 << 1
  R_OK = 1 << 2
end

class File < FileDescriptorIO
  # The file/directory separator character. '/' in unix, '\\' in windows.
  SEPARATOR = ifdef windows; '\\'; else; '/'; end

  # The file/directory separator string. "/" in unix, "\\" in windows.
  SEPARATOR_STRING = ifdef windows; "\\"; else; "/"; end

  # :nodoc:
  DEFAULT_CREATE_MODE = LibC::S_IRUSR | LibC::S_IWUSR | LibC::S_IRGRP | LibC::S_IROTH

  def initialize(filename, mode = "r", perm = DEFAULT_CREATE_MODE)
    oflag = open_flag(mode)

    fd = LibC.open(filename, oflag, perm)
    if fd < 0
      raise Errno.new("Error opening file '#{filename}' with mode '#{mode}'")
    end

    @path = filename
    super(fd, blocking: true)
  end

  protected def open_flag(mode)
    if mode.length == 0
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

    case mode.length
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

  def self.stat(path)
    if LibC.stat(path, out stat) != 0
      raise Errno.new("Unable to get stat for '#{path}'")
    end
    Stat.new(stat)
  end

  def self.lstat(path)
    if LibC.lstat(path, out stat) != 0
      raise Errno.new("Unable to get lstat for '#{path}'")
    end
    Stat.new(stat)
  end

  def self.exists?(filename)
    LibC.access(filename, LibC::F_OK) == 0
  end

  def self.file?(path)
    if LibC.stat(path, out stat) != 0
      return false
    end
    File::Stat.new(stat).file?
  end

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

    last = filename.length - 1
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
    basename = basename[0, basename.length - suffix.length] if basename.ends_with?(suffix)
    basename
  end

  def self.delete(filename)
    err = LibC.unlink(filename)
    if err == -1
      raise Errno.new("Error deleting file '#{filename}'")
    end
  end

  def self.extname(filename)
    dot_index = filename.rindex('.')

    if dot_index && dot_index != filename.length - 1  && filename[dot_index - 1] != SEPARATOR
      filename[dot_index, filename.length - dot_index]
    else
      ""
    end
  end

  def self.expand_path(path, dir = nil)
    if path.starts_with?('~')
      home = ENV["HOME"]
      if path.length >= 2 && path[1] == SEPARATOR
        path = home + path[1..-1]
      elsif path.length < 2
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
      false
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

  def self.read(filename)
    File.open(filename, "r") do |file|
      size = file.size.to_i
      String.new(size) do |buffer|
        file.read Slice.new(buffer, size)
        {size.to_i, 0}
      end
    end
  end

  def self.each_line(filename)
    File.open(filename, "r") do |file|
      file.each_line do |line|
        yield line
      end
    end
  end

  def self.read_lines(filename)
    lines = [] of String
    each_line(filename) do |line|
      lines << line
    end
    lines
  end

  def self.write(filename, content)
    File.open(filename, "w") do |file|
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

        if index != parts.length - 1 && part.ends_with?(SEPARATOR)
          byte_count -= 1
        end

        str.write part.unsafe_byte_slice(byte_start, byte_count)
      end
    end
  end

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

  def to_s(io)
    io << "#<File:" << @path
    io << " (closed)" if closed?
    io << ">"
    io
  end
end

require "file/stat"
