class StringIO
  include IO

  getter buffer
  getter length

  def initialize(capacity = 64)
    @buffer = GC.malloc_atomic(capacity.to_u32) as UInt8*
    @length = 0
    @capacity = capacity
    @pos = 0
  end

  def self.new(string : String)
    io = new(string.length)
    io << string
    io
  end

  def read(slice : Slice(UInt8), count)
    count = Math.min(count, @length - @pos)
    slice.copy_from(@buffer + @pos, count)
    @pos += count
    count
  end

  def write(slice : Slice(UInt8), count)
    new_length = length + count
    if new_length > @capacity
      resize_to_capacity(Math.pw2ceil(new_length))
    end

    slice.copy_to(@buffer + @length, count)
    @length += count

    self
  end

  def clear
    @length = 0
  end

  def empty?
    @length == 0
  end

  def to_s
    String.new @buffer, @length
  end

  def to_s(io)
    io.write Slice.new(@buffer, @length)
  end

  # private

  def check_needs_resize
    resize_to_capacity(@capacity * 2) if @length == @capacity
  end

  def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = @buffer.realloc(@capacity)
  end
end
