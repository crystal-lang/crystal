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
    @length_unknown = true

    self
  end

  def clear
    @bytesize = 0
  end

  def empty?
    @bytesize == 0
  end

  def to_s
    String.new @buffer, @bytesize
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
