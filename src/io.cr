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

  fun fcntl(fd : Int, cmd : FCNTL, ...) : Int
  fun getchar : Int
  fun putchar(c : Int) : Int
  fun puts(str : Char*) : Int
  fun printf(str : Char*, ...) : Int
  fun execl(path : Char*, arg0 : Char*, ...) : Int
  fun waitpid(pid : PidT, stat_loc : Int*, options : Int) : PidT
  fun open(path : Char*, oflag : Int, ...) : Int
  fun dup2(fd : Int, fd2 : Int) : Int
  fun read(fd : Int, buffer : Char*, nbyte : SizeT) : SSizeT
  fun write(fd : Int, buffer : Char*, nbyte : SizeT) : SSizeT
  fun pipe(filedes : Int[2]*) : Int
  fun select(nfds : Int, readfds : Void*, writefds : Void*, errorfds : Void*, timeout : TimeVal*) : Int
  fun lseek(fd : Int, offset  : OffT, whence : Int) : OffT
  fun close(fd : Int) : Int
  fun isatty(fd : Int) : Int
end

# The IO module is the basis for all input and output in Crystal.
#
# This module is included by types like `File`, `Socket` and `MemoryIO` and
# provide many useful methods for reading to and writing from an IO, like `print`, `puts`,
# `gets` and `printf`.
#
# The only requirement for a type including the IO module is to define
# these two methods:
#
# * `read(slice : Slice(UInt8))`: read at most *slice.size* bytes into *slice* and return the number of bytes read
# * `write(slice : Slice(UInt8))`: write at most *slice.size* bytes from *slice* and return the number of bytes written
#
# For example, this is a simple IO on top of a `Slice(UInt8)`:
#
# ```
# class SimpleSliceIO
#   include IO
#
#   def initialize(@slice : Slice(UInt8))
#   end
#
#   def read(slice : Slice(UInt8))
#     slice.size.times { |i| slice[i] = @slice[i] }
#     @slice += slice.size
#     count
#   end
#
#   def write(slice : Slice(UInt8))
#     slice.size.times { |i| @slice[i] = slice[i] }
#     @slice += slice.size
#     nil
#   end
# end
#
# slice = Slice.new(9) { |i| ('a'.ord + i).to_u8 }
# String.new(slice) #=> "abcdefghi"
#
# io = SimpleSliceIO.new(slice)
# io.gets(3) #=> "abc"
# io.print "xyz"
# String.new(slice) #=> "abcxyzghi"
# ```
module IO
  # Argument to a `seek` operation.
  enum Seek
    # Seeks to an absolute location
    Set    = 0

    # Seeks to a location relative to the current location
    # in the stream
    Current = 1

    # Seeks to a location relative to the end of the stream
    # (you probably want a negative value for the amount)
    End    = 2
  end

  # Raised when an IO operation times out.
  #
  # ```
  # STDIN.read_timeout = 1
  # STDIN.gets #=> IO::Timeout (after 1 second)
  # ```
  class Timeout < Exception
  end

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
      sec = LibC::TimeT.new(timeout_sec)

      if timeout_sec.is_a? Float
        usec = (timeout_sec-sec) * 10e6
      else
        usec = 0
      end

      timeout = LibC::TimeVal.new
      timeout.tv_sec = sec
      timeout.tv_usec = LibC::UsecT.new(usec)
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

  # Reads at most *slice.size* bytes from this IO into *slice*. Returns the number of bytes read.
  #
  # ```
  # io = MemoryIO.new "hello"
  # slice = Slice(UInt8).new(4)
  # io.read(slice) #=> 4
  # slice #=> [104, 101, 108, 108]
  # io.read(slice) #=> 1
  # slice #=> [111, 101, 108, 108]
  # ```
  abstract def read(slice : Slice(UInt8))

  # Writes the contents of *slice* into this IO.
  #
  # ```
  # io = MemoryIO.new
  # slice = Slice(UInt8).new(4) { |i| ('a'.ord + i).to_u8 }
  # io.write(slice)
  # io.to_s #=> "abcd"
  abstract def write(slice : Slice(UInt8)) : Nil

  # Flushes buffered data, if any.
  #
  # IO defines this is a no-op method, but including types may override.
  def flush
  end

  # Creates a pair of pipe endpoints (connected to each other) and returns them as a
  # two-element tuple.
  #
  # ```
  # reader, writer = IO.pipe
  # writer.puts "hello"
  # writer.puts "world"
  # reader.gets #=> "hello"
  # reader.gets #=> "world"
  # ```
  def self.pipe(read_blocking = false, write_blocking = false)
    if LibC.pipe(out pipe_fds) != 0
      raise Errno.new("Could not create pipe")
    end

    r = IO::FileDescriptor.new(pipe_fds[0], read_blocking)
    w = IO::FileDescriptor.new(pipe_fds[1], write_blocking)
    r.close_on_exec = true
    w.close_on_exec = true
    w.sync = true

    {r, w}
  end

  # Creates a pair of pipe endpoints (connected to each other) and passes them
  # to the given block. Both endpoints are closed after the block.
  #
  # ```
  # IO.pipe do |reader, writer|
  #   writer.puts "hello"
  #   writer.puts "world"
  #   reader.gets #=> "hello"
  #   reader.gets #=> "world"
  # end
  # ```
  def self.pipe(read_blocking = false, write_blocking = false)
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
  #
  # ```
  # io = MemoryIO.new
  # io << 1
  # io << '-'
  # io << "Crystal"
  # io.to_s #=> "1-Crystal"
  # ```
  def <<(obj) : self
    obj.to_s self
    self
  end

  # Same as `<<`
  #
  # ```
  # io = MemoryIO.new
  # io.print 1
  # io.print '-'
  # io.print "Crystal"
  # io.to_s #=> "1-Crystal"
  # ```
  def print(obj) : Nil
    self << obj
    nil
  end

  # Writes the given objects into this IO by invoking `to_s(io)`
  # on each of the objects.
  #
  # ```
  # io = MemoryIO.new
  # io.print 1, '-', "Crystal"
  # io.to_s #=> "1-Crystal"
  # ```
  def print(*objects : _) : Nil
    objects.each do |obj|
      print obj
    end
    nil
  end

  # Writes the given string to this IO followed by a newline character
  # unless the string already ends with one.
  #
  # ```
  # io = MemoryIO.new
  # io.puts "hello\n"
  # io.puts "world"
  # io.to_s #=> "hello\nworld\n"
  # ```
  def puts(string : String) : Nil
    self << string
    puts unless string.ends_with?('\n')
    nil
  end

  # Writes the given object to this IO followed by a newline character.
  #
  # ```
  # io = MemoryIO.new
  # io.puts 1
  # io.puts "Crystal"
  # io.to_s #=> "1\nCrystal\n"
  # ```
  def puts(obj) : Nil
    self << obj
    puts
  end

  # Writes a newline character.
  #
  # ```
  # io = MemoryIO.new
  # io.puts
  # io.to_s #=> "\n"
  # ```
  def puts : Nil
    write_byte '\n'.ord.to_u8
    nil
  end

  # Writes the given objects, each followed by a newline character.
  #
  # ```
  # io = MemoryIO.new
  # io.puts 1, '-', "Crystal"
  # io.to_s #=> "1\n-\nCrystal\n"
  # ```
  def puts(*objects : _) : Nil
    objects.each do |obj|
      puts obj
    end
    nil
  end

  def printf(format_string, *args) : Nil
    printf format_string, args
  end

  # ditto
  def printf(format_string, args : Array | Tuple) : Nil
    String::Formatter.new(format_string, args, self).format
    nil
  end

  # Reads a single byte from this IO. Returns `nil` if there is no more
  # data to read.
  #
  # ```
  # io = MemoryIO.new "a"
  # io.read_byte #=> 97
  # io.read_byte #=> nil
  # ```
  def read_byte : UInt8?
    byte :: UInt8
    if read(Slice.new(pointerof(byte), 1)) == 1
      byte
    else
      nil
    end
  end

  # Reads a single `Char` from this IO. Returns `nil` if there is no
  # more data to read.
  #
  # ```
  # io = MemoryIO.new "あ"
  # io.read_char #=> 'あ'
  # io.read_char #=> nil
  # ```
  def read_char : Char?
    info = read_char_with_bytesize
    info ? info[0] : nil
  end

  private def read_char_with_bytesize
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

  # Tries to read exactly `slice.size` bytes from this IO into `slice`.
  # Raises `EOFError` if there aren't `slice.size` bytes of data.
  #
  # ```
  # io = MemoryIO.new "123451234"
  # slice = Slice(UInt8).new(5)
  # io.read_fully(slice)
  # slice #=> [49, 50, 51, 52, 53]
  # io.read_fully #=> EOFError
  # ```
  def read_fully(slice : Slice(UInt8))
    count = slice.size
    while slice.size > 0
      read_bytes = read slice
      raise EOFError.new if read_bytes == 0
      slice += read_bytes
    end
    count
  end

  # Reads the rest of this IO data as a `String`.
  #
  # ```
  # io = MemoryIO.new "hello world"
  # io.read #=> "hello world"
  # io.read #=> ""
  # ```
  def gets_to_end : String
    buffer :: UInt8[2048]
    String.build do |str|
      while (read_bytes = read(buffer.to_slice)) > 0
        str.write buffer.to_slice[0, read_bytes]
      end
    end
  end

  # Reads a line from this IO. A line is terminated by the `\n` character.
  # Returns `nil` if called at the end of this IO.
  #
  # ```
  # io = MemoryIO.new "hello\nworld"
  # io.gets #=> "hello\n"
  # io.gets #=> "world"
  # io.gets #=> nil
  # ```
  def gets : String?
    gets '\n'
  end

  # Reads a line of at most `limit` bytes from this IO. A line is terminated by the `\n` character.
  # Returns `nil` if called at the end of this IO.
  #
  # ```
  # io = MemoryIO.new "hello\nworld"
  # io.gets(3) #=> "hel"
  # io.gets(3) #=> "lo\n"
  # io.gets(3) #=> "wor"
  # io.gets(3) #=> "ld"
  # io.gets(3) #=> nil
  # ```
  def gets(limit : Int) : String?
    gets '\n', limit
  end

  # Reads until *delimiter* is found, or the end of the IO is reached.
  # Returns `nil` if called at the end of this IO.
  #
  # ```
  # io = MemoryIO.new "hello\nworld"
  # io.gets('o') #=> "hello"
  # io.gets('r') #=> "\nwor"
  # io.gets('z') #=> "ld"
  # io.gets('w') #=> nil
  # ```
  def gets(delimiter : Char) : String?
    gets delimiter, Int32::MAX
  end

  # Reads until *delimiter* is found, `limit` bytes are read, or the end of the IO is reached.
  # Returns `nil` if called at the end of this IO.
  #
  # ```
  # io = MemoryIO.new "hello\nworld"
  # io.gets('o', 3) #=> "hel"
  # io.gets('r', 10) #=> "lo\nwor"
  # io.gets('z', 10) #=> "ld"
  # io.gets('w', 10) #=> nil
  # ```
  def gets(delimiter : Char, limit : Int) : String?
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

  # Reads until *delimiter* is found or the end of the IO is reached.
  # Returns `nil` if called at the end of this IO.
  #
  # ```
  # io = MemoryIO.new "hello\nworld"
  # io.gets("wo") #=> "hello\nwo"
  # io.gets("wo") #=> "rld"
  # io.gets("wo") #=> nil
  # ```
  def gets(delimiter : String) : String?
    # Empty string: read all
    if delimiter.empty?
      return gets_to_end
    end

    # One byte: use gets(Char)
    if delimiter.bytesize == 1
      return gets(delimiter.unsafe_byte_at(0).chr)
    end

    # One char: use gets(Char)
    if delimiter.size == 1
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

  # Same as `gets`, but raises `EOFError` if called at the end of this IO.
  def read_line(*args) : String?
    gets(*args) || raise EOFError.new
  end

  # Reads and discards *bytes_count* bytes.
  #
  # ```
  # io = MemoryIO.new "hello world"
  # io.skip(6)
  # io.gets #=> "world"
  # ```
  def skip(bytes_count : Int) : Nil
    buffer :: UInt8[1024]
    while bytes_count > 0
      read_count = read(buffer.to_slice[0, bytes_count])
      bytes_count -= read_count
    end
    nil
  end

  # Writes a single byte into this IO.
  #
  # ```
  # io = MemoryIO.new
  # io.write_byte 97_u8
  # io.to_s #=> "a"
  # ```
  def write_byte(byte : UInt8)
    x = byte
    write Slice.new(pointerof(x), 1)
  end

  def write_bytes(object, format = IO::ByteFormat::SystemEndian : IO::ByteFormat)
    object.to_io(self, format)
  end

  def read_bytes(type, format = IO::ByteFormat::SystemEndian : IO::ByteFormat)
    type.from_io(self, format)
  end

  # Returns `true` if this IO is associated with a terminal device (tty), `false` otherwise.
  #
  # IO returns `false`, but including types may override.
  #
  # ```
  # STDIN.tty?        #=> true
  # MemoryIO.new.tty? #=> false
  # ```
  def tty? : Bool
    false
  end

  # Invokes the given block with each *line* in this IO, where a line
  # is defined by the arguments passed to this method, which can be the same
  # ones as in the `gets` methods.
  #
  # ```
  # io = MemoryIO.new("hello\nworld")
  # io.each_line do |line|
  #   puts line.chomp.reverse
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # olleh
  # dlrow
  # ```
  def each_line(*args)
    while line = gets(*args)
      yield line
    end
  end

  # Returns an `Iterator` for the *lines* in this IO, where a line
  # is defined by the arguments passed to this method, which can be the same
  # ones as in the `gets` methods.
  #
  # ```
  # io = MemoryIO.new("hello\nworld")
  # iter = io.each_line
  # iter.next #=> "hello\n"
  # iter.next #=> "world"
  # ```
  def each_line(*args)
    LineIterator.new(self, args)
  end

  # Inovkes the given block with each `Char` in this IO.
  #
  # ```
  # io = MemoryIO.new("あめ")
  # io.each_char do |char|
  #   puts char
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # あ
  # め
  # ```
  def each_char
    while char = read_char
      yield char
    end
  end

  # Returns an `Iterator` for the chars in this IO.
  #
  # ```
  # io = MemoryIO.new("あめ")
  # iter = io.each_char
  # iter.next #=> 'あ'
  # iter.next #=> 'め'
  # ```
  def each_char
    CharIterator.new(self)
  end

  # Inovkes the given block with each byte (`UInt8`) in this IO.
  #
  # ```
  # io = MemoryIO.new("aあ")
  # io.each_byte do |byte|
  #   puts byte
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # 97
  # 227
  # 129
  # 130
  # ```
  def each_byte
    while byte = read_byte
      yield byte
    end
  end

  # Returns an `Iterator` for the bytes in this IO.
  #
  # ```
  # io = MemoryIO.new("aあ")
  # iter = io.each_byte
  # iter.next #=> 97
  # iter.next #=> 227
  # iter.next #=> 129
  # iter.next #=> 130
  # ```
  def each_byte
    ByteIterator.new(self)
  end

  # Copy all contents from *src* to *dst*.
  #
  # ```
  # io = MemoryIO.new "hello"
  # io2 = MemoryIO.new
  #
  # IO.copy io, io2
  #
  # io2.to_s #=> "hello"
  # ```
  def self.copy(src, dst)
    buffer :: UInt8[1024]
    count = 0
    while (len = src.read(buffer.to_slice).to_i32) > 0
      dst.write buffer.to_slice[0, len]
      count += len
    end
    len < 0 ? len : count
  end

  # :nodoc:
  struct LineIterator(I, A)
    include Iterator(String)

    def initialize(@io : I, @args : A)
    end

    def next
      @io.gets(*@args) || stop
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

