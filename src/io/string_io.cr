# An IO object that reads and writes from a string in memory.
class StringIO
  include IO

  # Returns the internal buffer as a `Pointer(UInt8)`.
  getter buffer

  # Same as `size`.
  getter bytesize

  # Creates an empty StringIO with the given initialize capactiy for
  # the internal buffer.
  #
  # ```
  # io = StringIO.new
  # io.pos  #=> 0
  # io.read #=> ""
  # ```
  def initialize(capacity = 64 : Int)
    String.check_capacity_in_bounds(capacity)

    @buffer = GC.malloc_atomic(capacity.to_u32) as UInt8*
    @bytesize = 0
    @capacity = capacity
    @pos = 0
    @closed = false
  end

  # Creates a StringIO whose contents are the contents of *string*
  # (which are duplicated, as strings are immutable).
  #
  # The IO starts at position zero for reading and writing.
  #
  # ```
  # io = StringIO.new "hello"
  # io.pos #=> 0
  # io.gets(2).should eq("he")
  # ```
  def self.new(string : String)
    io = new(string.bytesize)
    io << string
    io.rewind
    io
  end

  def read(slice : Slice(UInt8))
    count = slice.size
    count = Math.min(count, @bytesize - @pos)
    slice.copy_from(@buffer + @pos, count)
    @pos += count
    count
  end

  def write(slice : Slice(UInt8))
    check_open

    count = slice.size

    return count if count < 0

    new_bytesize = bytesize + count
    if new_bytesize > @capacity
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    slice.copy_to(@buffer + @pos, count)

    if @pos > @bytesize
      Intrinsics.memset((@buffer + @bytesize) as Void*, 0_u8, (@pos - @bytesize).to_u32, 0_u32, false)
    end

    @pos += count
    @bytesize = @pos if @pos > @bytesize

    count
  end

  # :nodoc:
  def gets(delimiter : Char, limit : Int32)
    if delimiter.ord >= 128
      return super
    end

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
    check_open

    pos = Math.min(@pos, @bytesize)

    if pos == @bytesize
      ""
    else
      String.new(@buffer + @pos, @bytesize - @pos)
    end
  end

  # Clears the internal buffer and resets the position to zero.
  #
  # ```
  # io = StringIO.new "hello"
  # io.gets(3) #=> "hel"
  # io.clear
  # io.pos     #=> 0
  # io.gets_to_end    #=> ""
  # ```
  def clear
    @bytesize = 0
    @pos = 0
  end

  # Returns `true` if this StringIO has no contents.
  #
  # ```
  # io = StringIO.new
  # io.empty? #=> true
  # io.print "hello"
  # io.empty? #=> false
  # ```
  def empty?
    @bytesize == 0
  end

  # Rewinds this IO to the initial position (zero).
  #
  # ```
  # io = StringIO.new "hello"
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
  # io = StringIO.new "hello"
  # io.size #=> 5
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
  # io = StringIO.new("abcdef")
  # io.gets(3) #=> "abc"
  # io.seek(1, IO::Seek::Set)
  # io.gets(2) #=> "bc"
  # io.seek(-1, IO::Seek::Current)
  # io.gets(1) #=> "c"
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
  # io = StringIO.new "hello"
  # io.pos     #=> 0
  # io.gets(2) #=> "he"
  # io.pos     #=> 2
  # ```
  def pos
    tell
  end

  # Sets the current position (in bytes) of this IO.
  #
  # ```
  # io = StringIO.new "hello"
  # io.pos = 3
  # io.gets #=> "lo"
  # ```
  def pos=(value)
    raise ArgumentError.new("negative pos") if value < 0

    @pos = value.to_i
  end

  # Closes this IO. Further operations on this IO will raise an `IO::Error`.
  #
  # ```
  # io = StringIO.new "hello"
  # io.close
  # io.gets_to_end #=> IO::Error: closed stream
  # ```
  def close
    @closed = true
  end

  # Determines if this IO is closed.
  #
  # ```
  # io = StringIO.new "hello"
  # io.closed? #=> false
  # io.close
  # io.closed? #=> true
  # ```
  def closed?
    @closed
  end

  # Returns a new String that contains the contents of the internal buffer.
  #
  # ```
  # io = StringIO.new
  # io.print 1, 2, 3
  # io.to_s #=> "123"
  # ```
  def to_s
    String.new @buffer, @bytesize
  end

  # Returns a Slice over the internal buffer. Modifying the slice
  # modifies the internal buffer.
  #
  # ```
  # io = StringIO.new "hello"
  # slice = io.to_slice
  # slice[0] = 97_u8
  # io.gets_to_end #=> "aello"
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

  private def check_needs_resize
    resize_to_capacity(@capacity * 2) if @bytesize == @capacity
  end

  private def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = @buffer.realloc(@capacity)
  end
end
