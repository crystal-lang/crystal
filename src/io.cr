lib LibC
  enum FCNTL
    F_GETFD = 1
    F_SETFD = 2
    F_GETFL = 3
    F_SETFL = 4
  end

  FD_CLOEXEC = 1

  ifdef linux
    O_RDONLY   = 0o0000000
    O_WRONLY   = 0o0000001
    O_RDWR     = 0o0000002
    O_APPEND   = 0o0002000
    O_CREAT    = 0o0000100
    O_TRUNC    = 0o0001000
    O_NONBLOCK = 0o0004000
    O_CLOEXEC  = 0o2000000
  elsif darwin
    O_RDONLY   = 0x0000
    O_WRONLY   = 0x0001
    O_RDWR     = 0x0002
    O_APPEND   = 0x0008
    O_CREAT    = 0x0200
    O_TRUNC    = 0x0400
    O_NONBLOCK = 0x0004
    O_CLOEXEC  = 0x1000000
  end

  S_IRWXU    = 0o000700         # RWX mask for owner
  S_IRUSR    = 0o000400         # R for owner
  S_IWUSR    = 0o000200         # W for owner
  S_IXUSR    = 0o000100         # X for owner
  S_IRWXG    = 0o000070         # RWX mask for group
  S_IRGRP    = 0o000040         # R for group
  S_IWGRP    = 0o000020         # W for group
  S_IXGRP    = 0o000010         # X for group
  S_IRWXO    = 0o000007         # RWX mask for other
  S_IROTH    = 0o000004         # R for other
  S_IWOTH    = 0o000002         # W for other
  S_IXOTH    = 0o000001         # X for other

  EWOULDBLOCK = 140
  EAGAIN      = 11

  fun fcntl(fd : Int32, cmd : FCNTL, ...) : Int32
  fun getchar : Char
  fun putchar(c : Char) : Char
  fun puts(str : UInt8*) : Int32
  fun printf(str : UInt8*, ...) : Char
  fun system(str : UInt8*) : Int32
  fun execl(path : UInt8*, arg0 : UInt8*, ...) : Int32
  fun waitpid(pid : Int32, stat_loc : Int32*, options : Int32) : Int32
  fun open(path : UInt8*, oflag : Int32, ...) : Int32
  fun dup2(fd : Int32, fd2 : Int32) : Int32
  fun read(fd : Int32, buffer : UInt8*, nbyte : LibC::SizeT) : LibC::SSizeT
  fun write(fd : Int32, buffer : UInt8*, nbyte : LibC::SizeT) : LibC::SSizeT
  fun pipe(filedes : Int32[2]*) : Int32
  fun select(nfds : Int32, readfds : Void*, writefds : Void*, errorfds : Void*, timeout : TimeVal*) : Int32

  # In fact lseek's offset is off_t, but it matches the definition of size_t
  fun lseek(fd : Int32, offset : LibC::SizeT, whence : Int32) : Int32
  fun close(fd : Int32) : Int32
  fun isatty(fd : Int32) : Int32
end

module IO
  def self.select(read_ios, write_ios = nil, error_ios = nil)
    select(read_ios, write_ios, error_ios, nil).not_nil!
  end

  # Returns an array of all given IOs that are
  # * ready to read if they appeared in read_ios
  # * ready to write if they appeared in write_ios
  # * have an error condition if they appeared in error_ios
  #
  # If the optional timeout_sec is given, nil is returned if no
  # IO was ready after the specified amount of seconds passed. Fractions
  # are supported.
  #
  # If timeout_sec is nil, this method blocks until an IO is ready.
  def self.select(read_ios, write_ios, error_ios, timeout_sec : LibC::TimeT|Int|Float?)
    nfds = 0
    read_ios.try &.each do |io|
      nfds = io.fd if io.fd > nfds
    end
    write_ios.try &.each do |io|
      nfds = io.fd if io.fd > nfds
    end
    error_ios.try &.each do |io|
      nfds = io.fd if io.fd > nfds
    end
    nfds += 1

    read_fdset  = FdSet.from_ios(read_ios)
    write_fdset = FdSet.from_ios(write_ios)
    error_fdset = FdSet.from_ios(error_ios)

    if timeout_sec
      sec = LibC::TimeT.cast(timeout_sec)

      if timeout_sec.is_a? Float
        usec = (timeout_sec-sec) * 10e6
      else
        usec = 0
      end

      timeout = LibC::TimeVal.new
      timeout.tv_sec = sec
      timeout.tv_usec = LibC::UsecT.cast(usec)
      timeout_ptr = pointerof(timeout)
    else
      timeout_ptr = Pointer(LibC::TimeVal).null
    end

    ret = LibC.select(nfds, read_fdset, write_fdset, error_fdset, timeout_ptr)
    case ret
    when 0 # Timeout
      nil
    when -1
      raise Errno.new("Error waiting with select()")
    else
      ios = [] of IO
      read_ios.try &.each do |io|
        ios << io if read_fdset.is_set(io)
      end
      write_ios.try &.each do |io|
        ios << io if write_fdset.is_set(io)
      end
      error_ios.try &.each do |io|
        ios << io if error_fdset.is_set(io)
      end
      ios
    end
  end

  # Reads count bytes from this IO into slice. Returns the number of bytes read.
  abstract def read(slice : Slice(UInt8), count)

  # Writes count bytes from slice into this IO. Returns the number of bytes written.
  abstract def write(slice : Slice(UInt8), count)

  def read(slice : Slice(UInt8))
    read slice, slice.length
  end

  def write(slice : Slice(UInt8))
    write slice, slice.length
  end

  def flush
  end

  def self.pipe(read_blocking=false, write_blocking=false)
    if LibC.pipe(out pipe_fds) != 0
      raise Errno.new("Could not create pipe")
    end

    r = FileDescriptorIO.new(pipe_fds[0], read_blocking)
    w = FileDescriptorIO.new(pipe_fds[1], write_blocking)
    r.close_on_exec = true
    w.close_on_exec = true
    w.sync = true

    {r, w}
  end

  def self.pipe(read_blocking=false, write_blocking=false)
    r, w = IO.pipe(read_blocking, write_blocking)
    begin
      yield r, w
    ensure
      w.flush
      r.close
      w.close
    end
  end

  # Writes the given object into this IO.
  # This ends up calling `to_s(io)` on the object.
  def <<(obj)
    obj.to_s self
    self
  end

  # Same as `<<`
  def print(obj)
    self << obj
  end

  def print(*objects : _)
    objects.each do |obj|
      print obj
    end
    nil
  end

  # Writes the given string to this IO followed by a newline character
  # unless the string already ends with one.
  def puts(string : String)
    self << string
    puts unless string.ends_with?('\n')
  end

  # Writes the given object to this IO followed by a newline character.
  def puts(obj)
    self << obj
    puts
  end

  def puts
    write_byte '\n'.ord.to_u8
  end

  def puts(*objects : _)
    objects.each do |obj|
      puts obj
    end
    nil
  end

  def printf(format_string, *args)
    printf format_string, args
  end

  def printf(format_string, args : Array | Tuple)
    String::Formatter.new(format_string, args, self).format
    nil
  end

  def read_byte
    byte :: UInt8
    if read(Slice.new(pointerof(byte), 1)) == 1
      byte
    else
      nil
    end
  end

  def read_char
    info = read_char_with_bytesize
    info ? info[0] : nil
  end

  def read_char_with_bytesize
    first = read_byte
    return nil unless first

    first = first.to_u32
    return first.chr, 1 if first < 0x80

    second = read_utf8_masked_byte
    return ((first & 0x1f) << 6 | second).chr, 2 if first < 0xe0

    third = read_utf8_masked_byte
    return ((first & 0x0f) << 12 | (second << 6) | third).chr, 3 if first < 0xf0

    fourth = read_utf8_masked_byte
    return ((first & 0x07) << 18 | (second << 12) | (third << 6) | fourth).chr, 4 if first < 0xf8

    raise InvalidByteSequenceError.new
  end

  private def read_utf8_masked_byte
    byte = read_byte || raise "Incomplete UTF-8 byte sequence"
    (byte & 0x3f).to_u32
  end

  def read_fully(buffer : Slice(UInt8))
    count = buffer.length
    while count > 0
      read_bytes = read(buffer, count)
      raise EOFError.new if read_bytes == 0
      count -= read_bytes
      buffer += read_bytes
    end
    count
  end

  def read
    buffer :: UInt8[2048]
    String.build do |str|
      while (read_bytes = read(buffer.to_slice)) > 0
        str.write(buffer.to_slice, read_bytes)
      end
    end
  end

  def read(length : Int)
    raise ArgumentError.new "negative length" if length < 0

    buffer :: UInt8[2048]
    String.build(length) do |str|
      while length > 0
        read_length = read(buffer.to_slice, length)
        break if read_length == 0

        str.write(buffer.to_slice, read_length)
        length -= read_length
      end
    end
  end

  def gets
    gets '\n'
  end

  def gets(limit : Int)
    gets '\n', limit
  end

  def gets(delimiter : Char)
    gets delimiter, Int32::MAX
  end

  def gets(delimiter : Char, limit : Int)
    raise ArgumentError.new "negative limit" if limit < 0

    buffer = String::Builder.new
    total = 0
    while true
      info = read_char_with_bytesize
      unless info
        return buffer.empty? ? nil : buffer.to_s
      end

      char, char_bytesize = info

      buffer << char
      break if char == delimiter

      total += char_bytesize
      break if total >= limit
    end
    buffer.to_s
  end

  def gets(delimiter : String)
    # Empty string: read all
    if delimiter.empty?
      return read
    end

    # One byte: use gets(Char)
    if delimiter.bytesize == 1
      return gets(delimiter.unsafe_byte_at(0).chr)
    end

    # One char: use gets(Char)
    if delimiter.length == 1
      return gets(delimiter[0])
    end

    # The 'hard' case: we read until we match the last byte,
    # and then compare backwards
    last_byte = delimiter.byte_at(delimiter.bytesize - 1)
    total_bytes = 0

    buffer = String::Builder.new
    while true
      unless byte = read_byte
        return buffer.empty? ? nil : buffer.to_s
      end
      buffer.write_byte(byte)
      total_bytes += 1

      break if (byte == last_byte) &&
               (buffer.bytesize >= delimiter.bytesize) &&
               (buffer.buffer + total_bytes - delimiter.bytesize).memcmp(delimiter.to_unsafe, delimiter.bytesize) == 0
    end
    buffer.to_s
  end

  def read_line(*args)
    gets(*args) || raise EOFError.new
  end

  def write(array : Array(UInt8))
    write Slice.new(array.buffer, array.length)
  end

  def write_byte(byte : UInt8)
    x = byte
    write Slice.new(pointerof(x), 1)
  end

  def tty?
    false
  end

  def each_line
    while line = gets
      yield line
    end
  end

  def each_line
    LineIterator.new(self)
  end

  def each_char
    while char = read_char
      yield char
    end
  end

  def each_char
    CharIterator.new(self)
  end

  def each_byte
    while byte = read_byte
      yield byte
    end
  end

  def each_byte
    ByteIterator.new(self)
  end

  def self.copy(src, dst)
    buffer :: UInt8[1024]
    count = 0
    while (len = src.read(buffer.to_slice).to_i32) > 0
      dst.write(buffer.to_slice, len)
      count += len
    end
    len < 0 ? len : count
  end

  # :nodoc:
  struct LineIterator(I)
    include Iterator(String)

    def initialize(@io : I)
    end

    def next
      @io.gets || stop
    end

    def rewind
      @io.rewind
      self
    end
  end

  # :nodoc:
  struct CharIterator(I)
    include Iterator(Char)

    def initialize(@io : I)
    end

    def next
      @io.read_char || stop
    end

    def rewind
      @io.rewind
      self
    end
  end

  # :nodoc:
  struct ByteIterator(I)
    include Iterator(UInt8)

    def initialize(@io : I)
    end

    def next
      @io.read_byte || stop
    end

    def rewind
      @io.rewind
      self
    end
  end
end

require "./io/*"

