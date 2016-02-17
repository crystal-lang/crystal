# An IO that reads and writes from a buffer in memory.
#
# The internal buffer can be resizeable and/or writeable depending
# on how a MemoryIO is constructed.
class MemoryIO
  include IO

  # Returns the internal buffer as a `Pointer(UInt8)`.
  getter buffer

  # Same as `size`.
  getter bytesize

  # Creates an empty, resizeable and writeable MemoryIO with the given
  # initialize capactiy for the internal buffer.
  #
  # ```
  # io = MemoryIO.new
  # io.pos  # => 0
  # io.read # => ""
  # ```
  def initialize(capacity = 64 : Int)
    String.check_capacity_in_bounds(capacity)

    @buffer = GC.malloc_atomic(capacity.to_u32) as UInt8*
    @bytesize = 0
    @capacity = capacity
    @pos = 0
    @closed = false
    @resizeable = true
    @writeable = true
  end

  # Creates a MemoryIO that will read, and optionally write, from/to
  # the given slice. The created MemoryIO is non-resizeable.
  #
  # The IO starts at position zero for reading.
  #
  # ```
  # slice = Slice.new(6) { |i| ('a'.ord + i).to_u8 }
  # io = MemoryIO.new slice, writeable: false
  # io.pos  # => 0
  # io.read # => "abcdef"
  # ```
  def initialize(slice : Slice(UInt8), writeable = true)
    @buffer = slice.to_unsafe
    @bytesize = @capacity = slice.size
    @pos = 0
    @closed = false
    @resizeable = false
    @writeable = writeable
  end

  # Creates a MemoryIO whose contents are the exact contents of *string*.
  # The created MemoryIO is non-resizeable and non-writeable.
  #
  # The IO starts at position zero for reading.
  #
  # ```
  # io = MemoryIO.new "hello"
  # io.pos        # => 0
  # io.gets(2)    # => "he"
  # io.print "hi" # raises
  # ```
  def self.new(string : String)
    new string.to_slice, writeable: false
  end

  # See `IO#read(slice)`.
  def read(slice : Slice(UInt8))
    count = slice.size
    count = Math.min(count, @bytesize - @pos)
    slice.copy_from(@buffer + @pos, count)
    @pos += count
    count
  end

  # See `IO#write(slice)`. Raises if this MemoryIO is non-writeable,
  # or if it's non-resizeable and a resize is needed.
  def write(slice : Slice(UInt8))
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
      Intrinsics.memset((@buffer + @bytesize) as Void*, 0_u8, (@pos - @bytesize).to_u32, 0_u32, false)
    end

    @pos += count
    @bytesize = @pos if @pos > @bytesize

    nil
  end

  # See `IO#write_byte`. Raises if this MemoryIO is non-writeable,
  # or if it's non-resizeable and a resize is needed.
  def write_byte(byte : UInt8)
    check_writeable
    check_open

    new_bytesize = @pos + 1
    if new_bytesize > @capacity
      check_resizeable
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    (@buffer + @pos).value = byte

    if @pos > @bytesize
      Intrinsics.memset((@buffer + @bytesize) as Void*, 0_u8, (@pos - @bytesize).to_u32, 0_u32, false)
    end

    @pos += 1
    @bytesize = @pos if @pos > @bytesize

    nil
  end

  # :nodoc:
  def gets(delimiter : Char, limit : Int32)
    return super if @encoding || delimiter.ord >= 128

    check_open

    raise ArgumentError.new "negative limit" if limit < 0

    index = (@buffer + @pos).to_slice(@bytesize - @pos).index(delimiter.ord)
    if index
      if index > limit
        index = limit
      else
        index += 1
      end
    else
      index = @bytesize - @pos
      return nil if index == 0

      if index > limit
        index = limit
      end
    end

    string = String.new(@buffer + @pos, index)
    @pos += index
    string
  end

  # :nodoc:
  def read_byte
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

  # :nodoc:
  def gets_to_end
    return super if @encoding

    check_open

    pos = Math.min(@pos, @bytesize)

    if pos == @bytesize
      ""
    else
      String.new(@buffer + @pos, @bytesize - @pos)
    end
  end

  # Clears the internal buffer and resets the position to zero. Raises
  # if this MemoryIO is non-resizeable.
  #
  # ```
  # io = MemoryIO.new "hello"
  # io.gets(3) # => "hel"
  # io.clear
  # io.pos         # => 0
  # io.gets_to_end # => ""
  # ```
  def clear
    check_resizeable
    @bytesize = 0
    @pos = 0
  end

  # Returns `true` if this MemoryIO has no contents.
  #
  # ```
  # io = MemoryIO.new
  # io.empty? # => true
  # io.print "hello"
  # io.empty? # => false
  # ```
  def empty?
    @bytesize == 0
  end

  # Rewinds this IO to the initial position (zero).
  #
  # ```
  # io = MemoryIO.new "hello"
  # io.gets(2) => "he"
  # io.rewind
  # io.gets(2) #=> "he"
  # ```
  def rewind
    @pos = 0
    self
  end

  # Returns the total number of bytes in this IO.
  #
  # ```
  # io = MemoryIO.new "hello"
  # io.size # => 5
  # ```
  def size
    @bytesize
  end

  # Same as `pos`.
  def tell
    @pos
  end

  # Seeks to a given *offset* (in bytes) according to the *whence* argument.
  #
  # ```
  # io = MemoryIO.new("abcdef")
  # io.gets(3) # => "abc"
  # io.seek(1, IO::Seek::Set)
  # io.gets(2) # => "bc"
  # io.seek(-1, IO::Seek::Current)
  # io.gets(1) # => "c"
  # ```
  def seek(offset, whence = Seek::Set : Seek)
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

  # Returns the current position (in bytes) of this IO.
  #
  # ```
  # io = MemoryIO.new "hello"
  # io.pos     # => 0
  # io.gets(2) # => "he"
  # io.pos     # => 2
  # ```
  def pos
    tell
  end

  # Sets the current position (in bytes) of this IO.
  #
  # ```
  # io = MemoryIO.new "hello"
  # io.pos = 3
  # io.gets # => "lo"
  # ```
  def pos=(value)
    raise ArgumentError.new("negative pos") if value < 0

    @pos = value.to_i
  end

  # Closes this IO. Further operations on this IO will raise an `IO::Error`.
  #
  # ```
  # io = MemoryIO.new "hello"
  # io.close
  # io.gets_to_end # => IO::Error: closed stream
  # ```
  def close
    @closed = true
  end

  # Determines if this IO is closed.
  #
  # ```
  # io = MemoryIO.new "hello"
  # io.closed? # => false
  # io.close
  # io.closed? # => true
  # ```
  def closed?
    @closed
  end

  # Returns a new String that contains the contents of the internal buffer.
  #
  # ```
  # io = MemoryIO.new
  # io.print 1, 2, 3
  # io.to_s # => "123"
  # ```
  def to_s
    String.new @buffer, @bytesize
  end

  # Returns a Slice over the internal buffer. Modifying the slice
  # modifies the internal buffer.
  #
  # ```
  # io = MemoryIO.new "hello"
  # slice = io.to_slice
  # slice[0] = 97_u8
  # io.gets_to_end # => "aello"
  # ```
  def to_slice
    Slice.new(@buffer, @bytesize)
  end

  # Appends this internal buffer to the given IO.
  def to_s(io)
    io.write Slice.new(@buffer, @bytesize)
  end

  private def check_open
    if closed?
      raise IO::Error.new "closed stream"
    end
  end

  private def check_writeable
    unless @writeable
      raise IO::Error.new "read-only stream"
    end
  end

  private def check_resizeable
    unless @resizeable
      raise IO::Error.new "non-resizeable stream"
    end
  end

  private def check_needs_resize
    resize_to_capacity(@capacity * 2) if @bytesize == @capacity
  end

  private def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = @buffer.realloc(@capacity)
  end
end
