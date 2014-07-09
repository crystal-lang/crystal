lib C
  enum FCNTL
    F_GETFL = 3
    F_SETFL = 4
  end

  ifdef linux
    O_RDONLY   = 00000000
    O_WRONLY   = 00000001
    O_RDWR     = 00000002
    O_APPEND   = 00002000
    O_CREAT    = 00000100
    O_TRUNC    = 00001000
  elsif darwin
    O_RDONLY   = 0x0000
    O_WRONLY   = 0x0001
    O_RDWR     = 0x0002
    O_APPEND   = 0x0008
    O_CREAT    = 0x0200
    O_TRUNC    = 0x0400
  end

  S_IRWXU    = 0000700

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
  fun open(path : UInt8*, oflag : Int32, ...) : Int32
  fun dup2(fd : Int32, fd2 : Int32) : Int32
  fun read(fd : Int32, buffer : UInt8*, nbyte : C::SizeT) : C::SizeT
  fun write(fd : Int32, buffer : UInt8*, nbyte : C::SizeT)
  fun lseek(fd : Int32, offset : Int64, whence : Int32) : Int32
  fun close(fd : Int32) : Int32
end

module IO
  # Reads count bytes from this IO into buffer
  abstract def read(buffer : UInt8*, count)

  # Writes count bytes from buffer into this IO
  abstract def write(buffer : UInt8*, count)

  def <<(string : String)
    write string.cstr, string.length
    self
  end

  def <<(obj)
    obj.to_s self
    self
  end

  def print(string)
    self << string
  end

  def puts(string)
    self << string
    self << "\n"
  end

  def read_byte
    byte :: UInt8
    if read(pointerof(byte), 1) == 1
      byte
    else
      nil
    end
  end

  def read_fully(buffer : UInt8*, count)
    while count > 0
      read_bytes = read(buffer, count)
      raise "Unexpected EOF" if read_bytes == 0
      count -= read_bytes
      buffer += read_bytes
    end
    count
  end

  def gets
    buffer = StringIO.new
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

require "./io/*"

def gets
  STDIN.gets
end

def print(obj)
  STDOUT.print obj
  nil
end

def puts(obj = "")
  STDOUT.puts obj
end

def p(obj)
  obj.inspect(STDOUT)
  puts
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
