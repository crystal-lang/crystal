class File < FileDescriptorIO
  SEPARATOR = '/'

  def initialize(filename, mode)
    if mode.length == 0
      raise "invalid access mode #{mode}"
    end

    m = 0
    o = 0
    case mode[0]
    when 'r'
      m = C::O_RDONLY
    when 'w'
      m = C::O_WRONLY
      o = C::O_CREAT | C::O_TRUNC
    when 'a'
      m = C::O_WRONLY
      o = C::O_CREAT | C::O_APPEND
    else
      raise "invalid access mode #{mode}"
    end

    case mode.length
    when 1
      # Nothing
    when 2
      case mode[1]
      when '+'
        m = C::O_RDWR
      when 'b'
        # Nothing
      else
        raise "invalid access mode #{mode}"
      end
    else
      raise "invalid access mode #{mode}"
    end

    oflag = m | o

    fd = C.open(filename, oflag, C::S_IRWXU)
    if fd < 0
      raise Errno.new("Error opening file '#{filename}' with mode '#{mode}'")
    end

    super(fd)
  end

  def self.stat(path)
    if C.stat(path, out stat) != 0
      raise Errno.new("Unable to get stat for '#{path}'")
    end
    Stat.new(path)
  end

  def self.lstat(path)
    if C.lstat(path, out stat) != 0
      raise Errno.new("Unable to get lstat for '#{path}'")
    end
    Stat.new(stat)
  end

  def self.exists?(filename)
    C.access(filename, C::F_OK) == 0
  end

  def self.dirname(filename)
    index = filename.rindex SEPARATOR
    if index
      if index == 0
        "/"
      else
        filename[0, index]
      end
    else
      "."
    end
  end

  def self.basename(filename)
    return "" if filename.length == 0

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
    err = C.unlink(filename)
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
    if path.starts_with?("~")
      home = ENV["HOME"]
      if path.length >= 2 && path[1] == '/'
        path = home + path[1..-1]
      elsif path.length < 2
        return home
      end
    end

    unless path.starts_with?("/")
      dir = dir ? expand_path(dir) : Dir.working_directory
      path = dir + "/" + path
    end

    ifdef windows
      path = path.tr("\\", "/")
    end

    parts = path.split("/")
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

    ifdef windows
      items.join("/")
    else
      "/" + items.join("/")
    end
  end

  def self.open(filename, mode)
    file = File.new filename, mode
    begin
      yield file
    ensure
      file.close
    end
  end

  def self.read(filename)
    File.open(filename, "r") do |file|
      file.seek 0, SEEK_END
      size = file.tell
      file.seek 0, SEEK_SET
      String.new_with_length(size.to_i) do |buffer|
        file.read Slice.new(buffer, size)
      end
    end
  end

  def self.each_line(filename)
    File.open(filename, "r") do |file|
      while line = file.gets
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

  def self.join(parts = [] of String)
    return "" if parts.empty?

    parts.map_with_index do |part, index|
      if part
        lindex = 0
        while lindex < part.length
          break if part[lindex] != SEPARATOR
          lindex += 1
        end

        rindex = part.length - 1
        while rindex >= 0
          break if part[rindex] != SEPARATOR
          rindex -= 1
        end

        lindex -= 1 if index == 0 && lindex != 0
        rindex += 1 if index == parts.size - 1 && rindex + 1 != part.length

        part[lindex..rindex]
      end
    end.compact.join('/')
  end

  def self.size(filename)
    stat(filename).size
  end

  def self.rename(old_filename, new_filename)
    code = C.rename(old_filename, new_filename)
    if code != 0
      raise Errno.new("Error renaming file '#{old_filename}' to '#{new_filename}'")
    end
    code
  end

  def size
    stat.size
  end
end

require "file/stat"

class Pipe
  include IO

  def self.open(command, mode)
    pipe = new(command, mode)
    begin
      yield pipe
    ensure
      $exit = pipe.close
    end
  end

  def initialize(command, mode)
    @pipe = C.popen(command, mode)
    unless @pipe
      raise Errno.new("Error executing system command '#{command}'")
    end
  end

  def read(buffer : Slice(UInt8), count)
    C.fread(buffer.pointer, 1.to_sizet, count.to_sizet, @pipe)
  end

  def write(buffer : Slice(UInt8), count)
    C.fwrite(buffer.pointer, 1.to_sizet, count.to_sizet, @pipe)
  end

  def close
    C.pclose(@pipe)
  end
end

def system2(command)
  Pipe.open(command, "r") do |pipe|
    output = [] of String
    while line = pipe.gets
      output << line.chomp
    end
    output
  end
end
