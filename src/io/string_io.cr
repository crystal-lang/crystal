class StringIO
  include IO

  getter buffer
  getter bytesize

  def initialize(capacity = 64)
    @buffer = GC.malloc_atomic(capacity.to_u32) as UInt8*
    @bytesize = 0
    @capacity = capacity
    @pos = 0
  end

  def self.new(string : String)
    io = new(string.bytesize)
    io << string
    io
  end

  def read(slice : Slice(UInt8), count)
    count = Math.min(count, @bytesize - @pos)
    slice.copy_from(@buffer + @pos, count)
    @pos += count
    count
  end

  def write(slice : Slice(UInt8), count)
    new_bytesize = bytesize + count
    if new_bytesize > @capacity
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    slice.copy_to(@buffer + @bytesize, count)
    @bytesize += count

    count
  end

  def gets(delimiter : Char, limit : Int32)
    if delimiter.ord >= 128
      return super
    end

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

  def read(length : Int)
    raise ArgumentError.new "negative length" if length < 0

    if length <= @bytesize - @pos
      string = String.new(@buffer + @pos, length)
      @pos += length
      return string
    end

    super
  end

  def clear
    @bytesize = 0
  end

  def empty?
    @bytesize == 0
  end
  
  def eof?
    @pos == @bytesize
  end

  def rewind
    @pos = 0
    self
  end

  def close
    # Do nothing
    # TODO: maybe we do want to allow closing a StringIO,
    # although we would have to make a check every time
    # we read/write...
  end

  def closed?
    false
  end

  def to_s
    String.new @buffer, @bytesize
  end

  def to_slice
    Slice.new(@buffer, @bytesize)
  end

  def to_s(io)
    io.write Slice.new(@buffer, @bytesize)
  end

  private def check_needs_resize
    resize_to_capacity(@capacity * 2) if @bytesize == @capacity
  end

  private def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = @buffer.realloc(@capacity)
  end
end
