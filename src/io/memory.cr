# An `IO` that reads and writes from a buffer in memory.
#
# The internal buffer can be resizeable and/or writeable depending
# on how an `IO::Memory` is constructed.
class IO::Memory < IO
  # Returns the internal buffer as a `Pointer(UInt8)`.
  getter buffer : Pointer(UInt8)

  # Same as `size`.
  getter bytesize : Int32

  @capacity : Int32

  # Creates an empty, resizeable and writeable `IO::Memory` with the given
  # initial *capacity* for the internal buffer.
  #
  # ```
  # io = IO::Memory.new
  # slice = Bytes.new(1)
  # io.pos         # => 0
  # io.read(slice) # => 0
  # slice          # => Bytes[0]
  # ```
  def initialize(capacity : Int = 64)
    String.check_capacity_in_bounds(capacity)

    @buffer = GC.malloc_atomic(capacity.to_u32).as(UInt8*)
    @bytesize = 0
    @capacity = capacity.to_i
    @pos = 0
    @closed = false
    @resizeable = true
    @writeable = true
  end

  # Creates an `IO::Memory` that will read, and optionally write, from/to
  # the given slice. The created `IO::Memory` is non-resizeable.
  #
  # The IO starts at position zero for reading.
  #
  # ```
  # slice = Slice.new(6) { |i| ('a'.ord + i).to_u8 }
  # io = IO::Memory.new slice, writeable: false
  # io.pos            # => 0
  # io.read(slice)    # => 6
  # String.new(slice) # => "abcdef"
  # ```
  def initialize(slice : Bytes, writeable = true)
    @buffer = slice.to_unsafe
    @bytesize = @capacity = slice.size.to_i
    @pos = 0
    @closed = false
    @resizeable = false
    @writeable = !slice.read_only? && writeable
  end

  # Creates an `IO::Memory` whose contents are the exact contents of *string*.
  # The created `IO::Memory` is non-resizeable and non-writeable.
  #
  # The `IO` starts at position zero for reading.
  #
  # ```
  # io = IO::Memory.new "hello"
  # io.pos        # => 0
  # io.gets(2)    # => "he"
  # io.print "hi" # raises IO::Error
  # ```
  def self.new(string : String)
    new string.to_slice, writeable: false
  end

  # See `IO#read(slice)`.
  def read(slice : Bytes) : Int32
    check_open

    count = slice.size
    count = Math.min(count, @bytesize - @pos)
    slice.copy_from(@buffer + @pos, count)
    @pos += count
    count
  end

  # See `IO#write(slice)`. Raises if this `IO::Memory` is non-writeable,
  # or if it's non-resizeable and a resize is needed.
  def write(slice : Bytes) : Nil
    check_writeable
    check_open

    count = slice.size

    return if count == 0

    new_bytesize = @pos + count
    if new_bytesize > @capacity
      check_resizeable
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    slice.copy_to(@buffer + @pos, count)

    if @pos > @bytesize
      (@buffer + @bytesize).clear(@pos - @bytesize)
    end

    @pos += count
    @bytesize = @pos if @pos > @bytesize
  end

  # See `IO#write_byte`. Raises if this `IO::Memory` is non-writeable,
  # or if it's non-resizeable and a resize is needed.
  def write_byte(byte : UInt8) : Nil
    check_writeable
    check_open

    new_bytesize = @pos + 1
    if new_bytesize > @capacity
      check_resizeable
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    (@buffer + @pos).value = byte

    if @pos > @bytesize
      (@buffer + @bytesize).clear(@pos - @bytesize)
    end

    @pos += 1
    @bytesize = @pos if @pos > @bytesize

    nil
  end

  # :nodoc:
  def gets(delimiter : Char, limit : Int32, chomp = false) : String?
    return super if @encoding || delimiter.ord >= 128

    check_open

    raise ArgumentError.new "Negative limit" if limit < 0

    index = (@buffer + @pos).to_slice(@bytesize - @pos).index(delimiter.ord)
    if index
      if index >= limit
        index = limit
      else
        index += 1
      end
    else
      index = @bytesize - @pos
      return nil if index == 0

      if index >= limit
        index = limit
      end
    end

    advance = index

    if chomp && index > 0 && (@buffer + @pos + index - 1).value === delimiter
      index -= 1

      if delimiter == '\n' && index > 0 && (@buffer + @pos + index - 1).value === '\r'
        index -= 1
      end
    end

    string = String.new(@buffer + @pos, index)
    @pos += advance
    string
  end

  def read_byte : UInt8?
    check_open

    pos = Math.min(@pos, @bytesize)

    if pos == @bytesize
      nil
    else
      byte = @buffer[@pos]
      @pos += 1
      byte
    end
  end

  def peek : Bytes
    check_open

    Slice.new(@buffer + @pos, @bytesize - @pos, read_only: !@writeable)
  end

  # :nodoc:
  def skip(bytes_count) : Nil
    check_open

    available = @bytesize - @pos
    if available >= bytes_count
      @pos += bytes_count
    else
      raise IO::EOFError.new
    end
  end

  def skip_to_end : Nil
    check_open

    @pos = @bytesize
  end

  # :inherit:
  def gets_to_end : String
    return super if @encoding

    check_open

    if @pos >= @bytesize
      ""
    else
      str = String.new(@buffer + @pos, @bytesize - @pos)
      @pos = @bytesize
      str
    end
  end

  # :inherit:
  def getb_to_end : Bytes
    check_open

    if @pos >= @bytesize
      Bytes[]
    else
      bytes = Slice.new(@buffer + @pos, @bytesize - @pos).dup
      @pos = @bytesize
      bytes
    end
  end

  # Clears the internal buffer and resets the position to zero.
  # Raises if this `IO::Memory` is non-resizeable.
  #
  # ```
  # io = IO::Memory.new
  # io << "abc"
  # io.rewind
  # io.gets(1) # => "a"
  # io.clear
  # io.pos         # => 0
  # io.gets_to_end # => ""
  #
  # io = IO::Memory.new "hello"
  # io.clear # raises IO::Error
  # ```
  def clear : Nil
    check_open
    check_resizeable
    @bytesize = 0
    @pos = 0
  end

  # Returns `true` if this `IO::Memory` has no contents.
  #
  # ```
  # io = IO::Memory.new
  # io.empty? # => true
  # io.print "hello"
  # io.empty? # => false
  # ```
  def empty? : Bool
    @bytesize == 0
  end

  # Rewinds this `IO` to the initial position (zero).
  #
  # ```
  # io = IO::Memory.new "hello"
  # io.gets(2) # => "he"
  # io.rewind
  # io.gets(2) # => "he"
  # ```
  def rewind : self
    @pos = 0
    self
  end

  # Returns the total number of bytes in this `IO`.
  #
  # ```
  # io = IO::Memory.new "hello"
  # io.size # => 5
  # ```
  def size : Int32
    @bytesize
  end

  # Seeks to a given *offset* (in bytes) according to the *whence* argument.
  #
  # ```
  # io = IO::Memory.new("abcdef")
  # io.gets(3) # => "abc"
  # io.seek(1, IO::Seek::Set)
  # io.gets(2) # => "bc"
  # io.seek(-1, IO::Seek::Current)
  # io.gets(1) # => "c"
  # ```
  def seek(offset, whence : Seek = Seek::Set)
    check_open

    case whence
    when Seek::Set
      # Nothing
    when Seek::Current
      offset += @pos
    when Seek::End
      offset += @bytesize
    end

    self.pos = offset
  end

  # Returns the current position (in bytes) of this `IO`.
  #
  # ```
  # io = IO::Memory.new "hello"
  # io.pos     # => 0
  # io.gets(2) # => "he"
  # io.pos     # => 2
  # ```
  def pos : Int32
    @pos
  end

  # Sets the current position (in bytes) of this `IO`.
  #
  # ```
  # io = IO::Memory.new "hello"
  # io.pos = 3
  # io.gets # => "lo"
  # ```
  def pos=(value)
    raise ArgumentError.new("Negative pos") if value < 0

    @pos = value.to_i
  end

  # Yields an `IO::Memory` to read a section of this `IO`'s buffer.
  #
  # During the block duration `self` becomes read-only,
  # so multiple concurrent open are allowed.
  def read_at(offset, bytesize, & : IO ->)
    unless 0 <= offset <= @bytesize
      raise ArgumentError.new("Offset out of bounds")
    end

    if bytesize < 0
      raise ArgumentError.new("Negative bytesize")
    end

    unless 0 <= offset + bytesize <= @bytesize
      raise ArgumentError.new("Bytesize out of bounds")
    end

    old_writeable = @writeable
    old_resizeable = @resizeable
    io = IO::Memory.new(to_slice[offset, bytesize], writeable: false)
    begin
      @writeable = false
      @resizeable = false
      yield io
    ensure
      io.close
      @writeable = old_writeable
      @resizeable = old_resizeable
    end
  end

  # Closes this `IO`. Further operations on this `IO` will raise an `IO::Error`.
  #
  # ```
  # io = IO::Memory.new "hello"
  # io.close
  # io.gets_to_end # raises IO::Error (closed stream)
  # ```
  def close : Nil
    @closed = true
  end

  # Determines if this `IO` is closed.
  #
  # ```
  # io = IO::Memory.new "hello"
  # io.closed? # => false
  # io.close
  # io.closed? # => true
  # ```
  def closed? : Bool
    @closed
  end

  # Returns a new `String` that contains the contents of the internal buffer.
  #
  # ```
  # io = IO::Memory.new
  # io.print 1, 2, 3
  # io.to_s # => "123"
  # ```
  def to_s : String
    if encoding = @encoding
      {% if flag?(:without_iconv) %}
        raise NotImplementedError.new("String.encode")
      {% else %}
        String.new to_slice, encoding: encoding.name, invalid: encoding.invalid
      {% end %}
    else
      String.new @buffer, @bytesize
    end
  end

  # Returns the underlying bytes.
  #
  # ```
  # io = IO::Memory.new
  # io.print "hello"
  #
  # io.to_slice # => Bytes[104, 101, 108, 108, 111]
  # ```
  def to_slice : Bytes
    Slice.new(@buffer, @bytesize, read_only: !@writeable)
  end

  # Appends this internal buffer to the given `IO`.
  def to_s(io : IO) : Nil
    if io == self
      # When appending to itself, we need to pull the resize up before taking
      # pointer to the buffer. It would become invalid when a resize happens during `#write`.
      new_bytesize = bytesize * 2
      resize_to_capacity(new_bytesize) if @capacity < new_bytesize
    end
    if encoding = @encoding
      {% if flag?(:without_iconv) %}
        raise NotImplementedError.new("String.encode")
      {% else %}
        String.encode(to_slice, encoding.name, io.encoding, io, io.@encoding.try(&.invalid))
      {% end %}
    else
      io.write(to_slice)
    end
  end

  private def check_writeable
    unless @writeable
      raise IO::Error.new "Read-only stream"
    end
  end

  private def check_resizeable
    unless @resizeable
      raise IO::Error.new "Non-resizeable stream"
    end
  end

  private def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = GC.realloc(@buffer, @capacity)
  end
end
