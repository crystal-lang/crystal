require "c/fcntl"
require "c/stdio"
require "c/sys/select"
require "c/sys/wait"
require "c/errno"
require "c/unistd"

# The IO module is the basis for all input and output in Crystal.
#
# This module is included by types like `File`, `Socket` and `IO::Memory` and
# provide many useful methods for reading to and writing from an IO, like `print`, `puts`,
# `gets` and `printf`.
#
# The only requirement for a type including the IO module is to define
# these two methods:
#
# * `read(slice : Slice(UInt8))`: read at most *slice.size* bytes into *slice* and return the number of bytes read
# * `write(slice : Slice(UInt8))`: write the whole *slice* into the IO
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
# String.new(slice) # => "abcdefghi"
#
# io = SimpleSliceIO.new(slice)
# io.gets(3) # => "abc"
# io.print "xyz"
# String.new(slice) # => "abcxyzghi"
# ```
#
# ### Encoding
#
# An IO can be set an encoding with the `#set_encoding` method. When this is
# set, all string operations (`gets`, `gets_to_end`, `read_char`, `<<`, `print`, `puts`
# `printf`) will write in the given encoding, and read from the given encoding.
# Byte operations (`read`, `write`, `read_byte`, `write_byte`) never do
# encoding/decoding operations.
#
# If an encoding is not set, the default one is UTF-8.
#
# Mixing string and byte operations might not give correct results and should be
# avoided, as string operations might need to read extra bytes in order to get characters
# in the given encoding.
module IO
  # Argument to a `seek` operation.
  enum Seek
    # Seeks to an absolute location
    Set = 0

    # Seeks to a location relative to the current location
    # in the stream
    Current = 1

    # Seeks to a location relative to the end of the stream
    # (you probably want a negative value for the amount)
    End = 2
  end

  # Raised when an IO operation times out.
  #
  # ```
  # STDIN.read_timeout = 1
  # STDIN.gets # => IO::Timeout (after 1 second)
  # ```
  class Timeout < Exception
  end

  def self.select(read_ios, write_ios = nil, error_ios = nil)
    self.select(read_ios, write_ios, error_ios, nil).not_nil!
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
  def self.select(read_ios, write_ios, error_ios, timeout_sec : LibC::TimeT | Int | Float?)
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

    read_fdset = FDSet.from_ios(read_ios)
    write_fdset = FDSet.from_ios(write_ios)
    error_fdset = FDSet.from_ios(error_ios)

    if timeout_sec
      sec = LibC::TimeT.new(timeout_sec)

      if timeout_sec.is_a? Float
        usec = (timeout_sec - sec) * 10e6
      else
        usec = 0
      end

      timeout = LibC::Timeval.new
      timeout.tv_sec = sec
      timeout.tv_usec = LibC::SusecondsT.new(usec)
      timeout_ptr = pointerof(timeout)
    else
      timeout_ptr = Pointer(LibC::Timeval).null
    end

    readfds_ptr = pointerof(read_fdset).as(LibC::FdSet*)
    writefds_ptr = pointerof(write_fdset).as(LibC::FdSet*)
    errorfds_ptr = pointerof(error_fdset).as(LibC::FdSet*)

    ret = LibC.select(nfds, readfds_ptr, writefds_ptr, errorfds_ptr, timeout_ptr)
    case ret
    when 0 # Timeout
      nil
    when -1
      raise Errno.new("Error waiting with select()")
    else
      ios = [] of IO
      read_ios.try &.each do |io|
        ios << io if read_fdset.set?(io)
      end
      write_ios.try &.each do |io|
        ios << io if write_fdset.set?(io)
      end
      error_ios.try &.each do |io|
        ios << io if error_fdset.set?(io)
      end
      ios
    end
  end

  # Reads at most *slice.size* bytes from this IO into *slice*. Returns the number of bytes read.
  #
  # ```
  # io = IO::Memory.new "hello"
  # slice = Slice(UInt8).new(4)
  # io.read(slice) # => 4
  # slice          # => [104, 101, 108, 108]
  # io.read(slice) # => 1
  # slice          # => [111, 101, 108, 108]
  # ```
  abstract def read(slice : Slice(UInt8))

  # Writes the contents of *slice* into this IO.
  #
  # ```
  # io = IO::Memory.new
  # slice = Slice(UInt8).new(4) { |i| ('a'.ord + i).to_u8 }
  # io.write(slice)
  # io.to_s #=> "abcd"
  abstract def write(slice : Slice(UInt8)) : Nil

  # Closes this IO.
  #
  # IO defines this is a no-op method, but including types may override.
  def close
  end

  # Returns `true` if this IO is closed.
  #
  # IO defines returns `false`, but including types may override.
  def closed?
    false
  end

  protected def check_open
    raise IO::Error.new "closed stream" if closed?
  end

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
  # reader.gets # => "hello"
  # reader.gets # => "world"
  # ```
  def self.pipe(read_blocking = false, write_blocking = false)
    pipe_fds = uninitialized StaticArray(LibC::Int, 2)
    if LibC.pipe(pipe_fds) != 0
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
  #   reader.gets # => "hello"
  #   reader.gets # => "world"
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
  # io = IO::Memory.new
  # io << 1
  # io << '-'
  # io << "Crystal"
  # io.to_s # => "1-Crystal"
  # ```
  def <<(obj) : self
    obj.to_s self
    self
  end

  # Same as `<<`
  #
  # ```
  # io = IO::Memory.new
  # io.print 1
  # io.print '-'
  # io.print "Crystal"
  # io.to_s # => "1-Crystal"
  # ```
  def print(obj) : Nil
    self << obj
    nil
  end

  # Writes the given objects into this IO by invoking `to_s(io)`
  # on each of the objects.
  #
  # ```
  # io = IO::Memory.new
  # io.print 1, '-', "Crystal"
  # io.to_s # => "1-Crystal"
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
  # io = IO::Memory.new
  # io.puts "hello\n"
  # io.puts "world"
  # io.to_s # => "hello\nworld\n"
  # ```
  def puts(string : String) : Nil
    self << string
    puts unless string.ends_with?('\n')
    nil
  end

  # Writes the given object to this IO followed by a newline character.
  #
  # ```
  # io = IO::Memory.new
  # io.puts 1
  # io.puts "Crystal"
  # io.to_s # => "1\nCrystal\n"
  # ```
  def puts(obj) : Nil
    self << obj
    puts
  end

  # Writes a newline character.
  #
  # ```
  # io = IO::Memory.new
  # io.puts
  # io.to_s # => "\n"
  # ```
  def puts : Nil
    print '\n'
    nil
  end

  # Writes the given objects, each followed by a newline character.
  #
  # ```
  # io = IO::Memory.new
  # io.puts 1, '-', "Crystal"
  # io.to_s # => "1\n-\nCrystal\n"
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
    String::Formatter(typeof(args)).new(format_string, args, self).format
    nil
  end

  # Reads a single byte from this IO. Returns `nil` if there is no more
  # data to read.
  #
  # ```
  # io = IO::Memory.new "a"
  # io.read_byte # => 97
  # io.read_byte # => nil
  # ```
  def read_byte : UInt8?
    byte = uninitialized UInt8
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
  # io = IO::Memory.new "あ"
  # io.read_char # => 'あ'
  # io.read_char # => nil
  # ```
  def read_char : Char?
    info = read_char_with_bytesize
    info ? info[0] : nil
  end

  private def read_char_with_bytesize
    first = read_utf8_byte
    return nil unless first

    first = first.to_u32
    return first.unsafe_chr, 1 if first < 0x80

    second = read_utf8_masked_byte
    return ((first & 0x1f) << 6 | second).unsafe_chr, 2 if first < 0xe0

    third = read_utf8_masked_byte
    return ((first & 0x0f) << 12 | (second << 6) | third).unsafe_chr, 3 if first < 0xf0

    fourth = read_utf8_masked_byte
    return ((first & 0x07) << 18 | (second << 12) | (third << 6) | fourth).unsafe_chr, 4 if first < 0xf8

    raise InvalidByteSequenceError.new("Unexpected byte 0x#{first.to_s(16)} in UTF-8 byte sequence")
  end

  private def read_utf8_masked_byte
    byte = read_utf8_byte || raise InvalidByteSequenceError.new("Incomplete UTF-8 byte sequence")
    (byte & 0x3f).to_u32
  end

  # Reads a single decoded UTF-8 byte from this IO. Returns `nil` if there is no more
  # data to read.
  #
  # If no encoding is set, this is the same as `#read_byte`.
  #
  # ```
  # bytes = "你".encode("GB2312") # => [196, 227]
  #
  # io = IO::Memory.new(bytes)
  # io.set_encoding("GB2312")
  # io.read_utf8_byte # => 228
  # io.read_utf8_byte # => 189
  # io.read_utf8_byte # => 160
  # io.read_utf8_byte # => nil
  #
  # "你".bytes # => [228, 189, 160]
  # ```
  def read_utf8_byte
    if decoder = decoder()
      decoder.read_byte(self)
    else
      read_byte
    end
  end

  # Reads UTF-8 decoded bytes into the given *slice*. Returns the number of UTF-8 bytes read.
  #
  # If no encoding is set, this is the same as `#read(slice)`.
  #
  # ```
  # bytes = "你".encode("GB2312") # => [196, 227]
  #
  # io = IO::Memory.new(bytes)
  # io.set_encoding("GB2312")
  #
  # buffer = uninitialized UInt8[1024]
  # bytes_read = io.read_utf8(buffer.to_slice) # => 3
  # buffer.to_slice[0, bytes_read]             # => [228, 189, 160]
  #
  # "你".bytes # => [228, 189, 160]
  # ```
  def read_utf8(slice : Slice(UInt8))
    if decoder = decoder()
      decoder.read_utf8(self, slice)
    else
      read(slice)
    end
  end

  # Writes a slice of UTF-8 encoded bytes to this IO, using the current encoding.
  def write_utf8(slice : Slice(UInt8))
    if encoder = encoder()
      encoder.write(self, slice)
    else
      write(slice)
    end
    nil
  end

  private def encoder
    if encoding = @encoding
      @encoder ||= Encoder.new(encoding)
    else
      nil
    end
  end

  private def decoder
    if encoding = @encoding
      @decoder ||= Decoder.new(encoding)
    else
      nil
    end
  end

  # Tries to read exactly `slice.size` bytes from this IO into `slice`.
  # Raises `EOFError` if there aren't `slice.size` bytes of data.
  #
  # ```
  # io = IO::Memory.new "123451234"
  # slice = Slice(UInt8).new(5)
  # io.read_fully(slice)
  # slice         # => [49, 50, 51, 52, 53]
  # io.read_fully # => EOFError
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
  # io = IO::Memory.new "hello world"
  # io.gets_to_end # => "hello world"
  # io.gets_to_end # => ""
  # ```
  def gets_to_end : String
    String.build do |str|
      if decoder = decoder()
        while true
          decoder.read(self)
          break if decoder.out_slice.empty?

          decoder.write(str)
        end
      else
        buffer = uninitialized UInt8[2048]
        while (read_bytes = read(buffer.to_slice)) > 0
          str.write buffer.to_slice[0, read_bytes]
        end
      end
    end
  end

  # Reads a line from this IO. A line is terminated by the `\n` character.
  # Returns `nil` if called at the end of this IO.
  #
  # ```
  # io = IO::Memory.new "hello\nworld"
  # io.gets # => "hello\n"
  # io.gets # => "world"
  # io.gets # => nil
  # ```
  def gets : String?
    gets '\n'
  end

  # Reads a line of at most `limit` bytes from this IO. A line is terminated by the `\n` character.
  # Returns `nil` if called at the end of this IO.
  #
  # ```
  # io = IO::Memory.new "hello\nworld"
  # io.gets(3) # => "hel"
  # io.gets(3) # => "lo\n"
  # io.gets(3) # => "wor"
  # io.gets(3) # => "ld"
  # io.gets(3) # => nil
  # ```
  def gets(limit : Int) : String?
    gets '\n', limit
  end

  # Reads until *delimiter* is found, or the end of the IO is reached.
  # Returns `nil` if called at the end of this IO.
  #
  # ```
  # io = IO::Memory.new "hello\nworld"
  # io.gets('o') # => "hello"
  # io.gets('r') # => "\nwor"
  # io.gets('z') # => "ld"
  # io.gets('w') # => nil
  # ```
  def gets(delimiter : Char) : String?
    gets delimiter, Int32::MAX
  end

  # Reads until *delimiter* is found, `limit` bytes are read, or the end of the IO is reached.
  # Returns `nil` if called at the end of this IO.
  #
  # ```
  # io = IO::Memory.new "hello\nworld"
  # io.gets('o', 3)  # => "hel"
  # io.gets('r', 10) # => "lo\nwor"
  # io.gets('z', 10) # => "ld"
  # io.gets('w', 10) # => nil
  # ```
  def gets(delimiter : Char, limit : Int) : String?
    raise ArgumentError.new "negative limit" if limit < 0

    # # If the char's representation is a single byte and we have an encoding,
    # search the delimiter in the buffer
    if delimiter.ascii? && (decoder = decoder())
      return decoder.gets(self, delimiter.ord.to_u8, limit)
    end

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
  # io = IO::Memory.new "hello\nworld"
  # io.gets("wo") # => "hello\nwo"
  # io.gets("wo") # => "rld"
  # io.gets("wo") # => nil
  # ```
  def gets(delimiter : String) : String?
    # Empty string: read all
    if delimiter.empty?
      return gets_to_end
    end

    # One byte: use gets(Char)
    if delimiter.bytesize == 1
      return gets(delimiter.unsafe_byte_at(0).unsafe_chr)
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
      unless byte = read_utf8_byte
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
  def read_line(*args, **options) : String?
    gets(*args, **options) || raise EOFError.new
  end

  # Reads and discards *bytes_count* bytes.
  #
  # ```
  # io = IO::Memory.new "hello world"
  # io.skip(6)
  # io.gets # => "world"
  # ```
  def skip(bytes_count : Int) : Nil
    buffer = uninitialized UInt8[1024]
    while bytes_count > 0
      read_count = read(buffer.to_slice[0, bytes_count])
      bytes_count -= read_count
    end
    nil
  end

  # Writes a single byte into this IO.
  #
  # ```
  # io = IO::Memory.new
  # io.write_byte 97_u8
  # io.to_s # => "a"
  # ```
  def write_byte(byte : UInt8)
    x = byte
    write Slice.new(pointerof(x), 1)
  end

  # Writes the given object to this IO using the specified *format*.
  #
  # This ends up invoking `object.to_io(self, format)`, so any object defining a
  # `to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)`
  # method can be written in this way.
  #
  # See `Int#to_io` and `Float#to_io`.
  #
  # ```
  # io = IO::Memory.new
  # io.write_bytes(0x01020304, IO::ByteFormat::LittleEndian)
  # io.rewind
  # io.gets(4) # => "\u{4}\u{3}\u{2}\u{1}"
  # ```
  def write_bytes(object, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
    object.to_io(self, format)
  end

  # Reads an instance of the given *type* from this IO using the specified *format*.
  #
  # This ends up invoking `type.from_io(self, format)`, so any type defining a
  # `from_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)`
  # method can be read in this way.
  #
  # See `Int#from_io` and `Float#from_io`.
  #
  # ```
  # io = IO::Memory.new
  # io.puts "\u{4}\u{3}\u{2}\u{1}"
  # io.rewind
  # io.read_bytes(Int32, IO::ByteFormat::LittleEndian) # => 0x01020304
  # ```
  def read_bytes(type, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
    type.from_io(self, format)
  end

  # Returns `true` if this IO is associated with a terminal device (tty), `false` otherwise.
  #
  # IO returns `false`, but including types may override.
  #
  # ```
  # STDIN.tty?          # => true
  # IO::Memory.new.tty? # => false
  # ```
  def tty? : Bool
    false
  end

  # Invokes the given block with each *line* in this IO, where a line
  # is defined by the arguments passed to this method, which can be the same
  # ones as in the `gets` methods.
  #
  # ```
  # io = IO::Memory.new("hello\nworld")
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
  def each_line(*args, **options)
    while line = gets(*args, **options)
      yield line
    end
  end

  # Returns an `Iterator` for the *lines* in this IO, where a line
  # is defined by the arguments passed to this method, which can be the same
  # ones as in the `gets` methods.
  #
  # ```
  # io = IO::Memory.new("hello\nworld")
  # iter = io.each_line
  # iter.next # => "hello\n"
  # iter.next # => "world"
  # ```
  def each_line(*args, **options)
    LineIterator.new(self, args, **options)
  end

  # Inovkes the given block with each `Char` in this IO.
  #
  # ```
  # io = IO::Memory.new("あめ")
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
  # io = IO::Memory.new("あめ")
  # iter = io.each_char
  # iter.next # => 'あ'
  # iter.next # => 'め'
  # ```
  def each_char
    CharIterator.new(self)
  end

  # Inovkes the given block with each byte (`UInt8`) in this IO.
  #
  # ```
  # io = IO::Memory.new("aあ")
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
  # io = IO::Memory.new("aあ")
  # iter = io.each_byte
  # iter.next # => 97
  # iter.next # => 227
  # iter.next # => 129
  # iter.next # => 130
  # ```
  def each_byte
    ByteIterator.new(self)
  end

  # Rewinds this IO. By default this method raises, but including types
  # mayb implement it.
  def rewind
    raise IO::Error.new("can't rewind")
  end

  # Sets the encoding of this IO.
  #
  # The *invalid* argument can be:
  # * `nil`: an exception is raised on invalid byte sequences
  # * `:skip`: invalid byte sequences are ignored
  #
  # String operations (`gets`, `gets_to_end`, `read_char`, `<<`, `print`, `puts`
  # `printf`) will use this encoding.
  def set_encoding(encoding : String, invalid : Symbol? = nil)
    if (encoding == "UTF-8") && (invalid != :skip)
      @encoding = nil
    else
      @encoding = EncodingOptions.new(encoding, invalid)
    end
    @encoder.try &.close
    @decoder.try &.close
    @encoder = nil
    @decoder = nil
    nil
  end

  # Returns this IO's encoding. The default is UTF-8.
  def encoding : String
    @encoding.try(&.name) || "UTF-8"
  end

  # Copy all contents from *src* to *dst*.
  #
  # ```
  # io = IO::Memory.new "hello"
  # io2 = IO::Memory.new
  #
  # IO.copy io, io2
  #
  # io2.to_s # => "hello"
  # ```
  def self.copy(src, dst)
    buffer = uninitialized UInt8[1024]
    count = 0
    while (len = src.read(buffer.to_slice).to_i32) > 0
      dst.write buffer.to_slice[0, len]
      count += len
    end
    len < 0 ? len : count
  end

  # Copy at most *limit* bytes from *src* to *dst*.
  #
  # ```
  # io = IO::Memory.new "hello"
  # io2 = IO::Memory.new
  #
  # IO.copy io, io2, 3
  #
  # io2.to_s # => "hel"
  # ```
  def self.copy(src, dst, limit : Int)
    raise ArgumentError.new("negative limit") if limit < 0

    buffer = uninitialized UInt8[1024]
    remaining = limit
    while (len = src.read(buffer.to_slice[0, Math.min(buffer.size, Math.max(remaining, 0))])) > 0
      dst.write buffer.to_slice[0, len]
      remaining -= len
    end
    limit - remaining
  end

  private struct LineIterator(I, A)
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

  private struct CharIterator(I)
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

  private struct ByteIterator(I)
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
