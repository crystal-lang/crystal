lib C
  enum FCNTL
    F_GETFL = 3
    F_SETFL = 4
  end

  enum FD
    O_NONBLOCK = 04000
  end

  EWOULDBLOCK = 140
  EAGAIN      = 11

  fun fcntl(fd : Int32, cmd : Int32, ...) : Int32
  fun getchar : Char
  fun putchar(c : Char) : Char
  fun puts(str : UInt8*) : Int32
  fun printf(str : UInt8*, ...) : Char
  fun system(str : UInt8*) : Int32
  fun execl(path : UInt8*, arg0 : UInt8*, ...) : Int32
  fun waitpid(pid : Int32, stat_loc : Int32*, options : Int32) : Int32
  fun open(path : UInt8*, oflag : Int32) : Int32
  fun dup2(fd : Int32, fd2 : Int32) : Int32
  fun read(fd : Int32, buffer : UInt8*, nbyte : C::SizeT) : C::SizeT
  fun write(fd : Int32, buffer : UInt8*, nbyte : C::SizeT)
  fun close(fd : Int32) : Int32
end

require "string/buffer"

# Classes including IO must define:
#
#   * read(buffer : UInt8*, count)
#     reads count bytes into buffer
#
#   * write(buffer : UInt8*, count)
#     writes count btyes from buffer
module IO
  def print(string)
    string = string.to_s
    write string.cstr, string.length
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
      unless ch = read_byte
        return buffer.empty? ? nil : buffer.to_s
      end

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
      if read_length == 0
        length -= remaining_length
        break
      end
      remaining_length -= read_length
      buffer_pointer += read_length
    end
    String.new(buffer as UInt8*, length.to_i)
  end

  def write(array : Array(UInt8))
    write array.buffer, array.length
  end

  def write_byte(byte : UInt8)
    x = byte
    write pointerof(x), 1
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
        if @buffer_rem_size <= 0
          if buffer.length == 0
            return nil
          else
            break
          end
        end

        endl = @buffer_rem.index('\n'.ord.to_u8, @buffer_rem_size)
        if endl >= 0
          buffer << String.new(@buffer_rem as UInt8*, endl + 1)
          @buffer_rem_size -= (endl + 1)
          @buffer_rem += (endl + 1)
          break
        else
          buffer << String.new(@buffer_rem as UInt8*, @buffer_rem_size)
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

  def write(buffer, count)
    @io.write buffer, count
  end

  def fill_buffer
    @buffer_rem_size = @io.read(@buffer, 16 * 1024).to_i
    @buffer_rem = @buffer
  end
end

class StringIO
  include IO

  def initialize(contents = nil)
    @buffer = String::Buffer.new
    @buffer << contents if contents
    @pos = 0
  end

  def read(buffer, count)
    count = Math.min(count, @buffer.length - @pos)
    buffer.memcpy(@buffer.buffer + @pos, count)
    @pos += count
    count
  end

  def write(bytes, count)
    @buffer.append (bytes as UInt8*), count
  end

  def buffer
    @buffer
  end

  def to_s
    @buffer.to_s
  end
end

class FileDescriptorIO
  include IO

  def initialize(@fd)
  end

  def read(buffer : UInt8*, count)
    C.read(@fd, buffer, count.to_sizet)
  end

  def read_nonblock(length)
    before = C.fcntl(fd, C::FCNTL::F_GETFL)
    C.fcntl(fd, C::FCNTL::F_SETFL, before | C::FD::O_NONBLOCK)

    begin
      buffer = Pointer(UInt8).malloc(length)
      read_length = read(buffer, length)
      if read_length == 0 || C.errno == C::EWOULDBLOCK || C.errno == C::EAGAIN
        # TODO: raise exception when errno != 0
        nil
      else
        String.new(buffer, read_length.to_i)
      end
    ensure
      C.fcntl(fd, C::FCNTL::F_SETFL, before)
    end
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
  puts "{{var}} = #{ {{var}} }"
end
