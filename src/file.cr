require "file/stat"

lib C
  type File : Void*

  fun fopen(filename : UInt8*, mode : UInt8*) : File
  fun fwrite(buf : UInt8*, size : C::SizeT, count : C::SizeT, fp : File) : SizeT
  fun fclose(file : File) : Int32
  fun feof(file : File) : Int32
  fun fflush(file : File) : Int32
  fun fread(buffer : UInt8*, size : C::SizeT, nitems : C::SizeT, file : File) : Int32
  fun access(filename : UInt8*, how : Int32) : Int32
  fun fileno(file : File) : Int32
  fun realpath(path : UInt8*, resolved_path : UInt8*) : UInt8*
  fun unlink(filename : UInt8*) : Int32
  fun popen(command : UInt8*, mode : UInt8*) : File
  fun pclose(stream : File) : Int32

  fun stat(path : UInt8*, stat : Stat*) : Int32
  fun lstat(path : UInt8*, stat : Stat *) : Int32
  fun fstat(fileno : Int32, stat : Stat*) : Int32
  fun rename(oldname : UInt8*, newname : UInt8*) : Int32

  ifdef x86_64
    fun fseeko(file : File, offset : Int64, whence : Int32) : Int32
    fun ftello(file : File) : Int64
  else
    fun fseeko = fseeko64(file : File, offset : Int64, whence : Int32) : Int32
    fun ftello = ftello64(file : File) : Int64
  end

  SEEK_SET = 0
  SEEK_CUR = 1
  SEEK_END = 2

  F_OK = 0
  X_OK = 1 << 0
  W_OK = 1 << 1
  R_OK = 1 << 2
end

class File
  include IO
  SEPARATOR = '/'

  module Seek
    Begin = C::SEEK_SET
    End = C::SEEK_END
  end

  def initialize(filename, mode)
    @file = C.fopen filename, mode
    unless @file
      raise Errno.new("Error opening file '#{filename}' with mode '#{mode}'")
    end
    initialize @file
  end

  def initialize(@file)
  end

  def read(buffer : UInt8*, count)
    C.fread(buffer, 1.to_sizet, count.to_sizet, @file)
  end

  def write(buffer : UInt8*, count)
    C.fwrite(buffer, 1.to_sizet, count.to_sizet, @file)
  end

  def close
    C.fclose(@file)
  end

  def seek(offset, origin)
    C.fseeko(@file, offset.to_i64, origin)
  end

  def tell
    C.ftello(@file)
  end

  def fileno
    C.fileno(@file)
  end

  def stat
    if C.fstat(fileno, out stat) != 0
      raise Errno.new("Unable to get stat")
    end
    Stat.new(stat)
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

  def self.expand_path(filename)
    str = C.realpath(filename, nil)
    unless str
      raise Errno.new("Error expanding path '#{filename}'")
    end

    String.new_and_free(str)
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
      file.seek 0, Seek::End
      size = file.tell
      file.seek 0, Seek::Begin
      String.new_with_length(size.to_i) do |buffer|
        file.read(buffer, size)
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

def system2(command)
  pipe = C.popen(command, "r")
  unless pipe
    raise Errno.new("Error executing system command '#{command}'")
  end
  begin
    stream = File.new(pipe)
    output = [] of String
    while line = stream.gets
      output << line.chomp
    end
    output
  ensure
    $exit = C.pclose(pipe)
  end
end
