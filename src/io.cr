lib C
  fun getchar : Char
  fun putchar(c : Char) : Char
  fun puts(str : Char*) : Int32
  fun printf(str : Char*, ...) : Char
  fun system(str : Char*) : Int32
  fun execl(path : Char*, arg0 : Char*, ...) : Int32
  fun waitpid(pid : Int32, stat_loc : Int32*, options : Int32) : Int32
  fun open(path : Char*, oflag : Int32) : Int32
  fun dup2(fd : Int32, fd2 : Int32) : Int32
  fun read(fd : Int32, buffer : UInt8*, nbyte : C::SizeT) : C::SizeT
  fun write(fd : Int32, buffer : UInt8*, nbyte : C::SizeT)
  fun close(fd : Int32) : Int32
end

require "string/buffer"

module IO
  def print(string)
    string = string.to_s
    write string.cstr as UInt8*, string.length
  end

  def <<(string)
    print(string)
    self
  end

  def puts(string)
    print string
    print "\n"
  end

  def read_byte
    byte :: UInt8
    if read(pointerof(byte), 1) == 1
      byte
    else
      nil
    end
  end

  def gets
    buffer = String::Buffer.new
    while true
      return nil unless ch = read_byte
      ch = ch.chr
      buffer << ch
      break if ch == '\n'
    end
    buffer.to_s
  end

  def read(length)
    buffer_pointer = buffer = Pointer(UInt8).malloc(length)
    remaining_length = length
    while remaining_length > 0
      read_length = read(buffer_pointer, remaining_length)
      remaining_length -= read_length
      buffer_pointer += read_length
    end
    String.new(buffer as Char*, length.to_i)
  end
end

class BufferedIO
  include IO

  def initialize(@io)
    @buffer = @buffer_rem = Pointer(UInt8).malloc(16 * 1024)
    @buffer_rem_size = 0
  end

  def gets
    String.build do |buffer|
      loop do
        fill_buffer if @buffer_rem_size == 0
        return nil if @buffer_rem_size <= 0

        endl = @buffer_rem.index('\n'.ord.to_u8, @buffer_rem_size)
        if endl >= 0
          buffer << String.new(@buffer_rem as Char*, endl + 1)
          @buffer_rem_size -= (endl + 1)
          @buffer_rem += (endl + 1)
          break
        else
          buffer << String.new(@buffer_rem as Char*, @buffer_rem_size)
          @buffer_rem_size = 0
        end
      end
    end
  end

  def read(buffer : UInt8*, count)
    fill_buffer if @buffer_rem_size == 0
    count = Math.min(count, @buffer_rem_size)
    buffer.memcpy(@buffer_rem, count)
    @buffer_rem += count
    @buffer_rem_size -= count
    count
  end

  def fill_buffer
    @buffer_rem_size = @io.read(@buffer, 16 * 1024)
    @buffer_rem = @buffer
  end
end

class StringIO
  def initialize(contents = nil)
    @buffer = String::Buffer.new
    @buffer << contents if contents
    @pos = 0
  end

  def <<(obj)
    @buffer << obj
  end

  def puts(obj)
    self << obj << "\n"
  end

  def print(obj)
    self << obj
  end

  def to_s
    @buffer.to_s
  end

  def gets
    return nil if @pos == @buffer.length
    finish = @pos
    while finish < @buffer.length && @buffer.buffer[finish] != '\n'
      finish += 1
    end
    str = String.new(@buffer.buffer + @pos, finish - @pos + 1)
    @pos = finish + 1
    str
  end

  def read(length)
    length = Math.min(length, @buffer.length - @pos)
    str = String.new(@buffer.buffer + @pos, length)
    @pos += length
    str
  end
end

class FileDescriptorIO
  include IO

  def initialize(@fd)
  end

  def read(buffer : UInt8*, count)
    C.read(@fd, buffer, count.to_sizet)
  end

  def write(buffer : UInt8*, count)
    C.write(@fd, buffer, count.to_sizet)
  end

  def fd
    @fd
  end

  def close
    if C.close(@fd) != 0
      raise Errno.new("Error closing file")
    end
  end
end

STDIN = FileDescriptorIO.new(0)
STDOUT = FileDescriptorIO.new(1)
STDERR = FileDescriptorIO.new(2)

def gets
  STDIN.gets
end

def print(obj : Char)
  C.putchar obj
  nil
end

def print(obj : Int32)
  C.printf "%d", obj
  nil
end

def print(obj : Int64)
  C.printf "%ld", obj
  nil
end

def print(obj : Float32)
  C.printf "%f", obj
  nil
end

def print(obj : Float64)
  C.printf "%g", obj
  nil
end

def print(obj)
  C.printf obj.to_s
  nil
end

def puts(obj : Char)
  C.printf "%c\n", obj
  nil
end

def puts(obj : Int8)
  C.printf "%hhd\n", obj
  nil
end

def puts(obj : Int16)
  C.printf "%hd\n", obj
  nil
end

def puts(obj : Int32)
  C.printf "%d\n", obj
  nil
end

def puts(obj : Int64)
  C.printf "%lld\n", obj
  nil
end

def puts(obj : UInt8)
  C.printf "%hhu\n", obj
  nil
end

def puts(obj : UInt16)
  C.printf "%hu\n", obj
  nil
end

def puts(obj : UInt32)
  C.printf "%u\n", obj
  nil
end

def puts(obj : UInt64)
  C.printf "%llu\n", obj
  nil
end

def puts(obj : Float32)
  C.printf "%g\n", obj.to_f64
  nil
end

def puts(obj : Float64)
  C.printf "%g\n", obj
  nil
end

def puts(obj = "")
  C.puts obj.to_s
  nil
end

def p(obj)
  puts obj.inspect
  obj
end

def system(command)
  pid = fork do
    # Redirect STDOUT to /dev/null
    null = C.open("/dev/null", 1)
    C.dup2(null, 1)

    C.execl("/bin/sh", command, "-c", command, nil)
  end

  if pid == -1
    raise Errno.new("Error executing system command '#{command}'")
  end

  C.waitpid(pid, out stat, 0)
  stat
end

macro pp(var)
  "puts \"#{var} = \#{#{var}}\""
end
