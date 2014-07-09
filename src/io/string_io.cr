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

  def read(buffer, count)
    count = Math.min(count, @length - @pos)
    buffer.memcpy(@buffer + @pos, count)
    @pos += count
    count
  end

  def write(buffer : UInt8*, count)
    new_length = length + count
    if new_length > @capacity
      cap2 = Math.log2(new_length).ceil
      new_capacity = 2 ** cap2
      resize_to_capacity(new_capacity)
    end

    (@buffer + @length).memcpy(buffer, count)
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
    io.write @buffer, @length
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
