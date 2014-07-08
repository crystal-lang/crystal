class StringBuffer
  def initialize(capacity = 64)
    @buffer = GC.malloc_atomic(capacity.to_u32) as UInt8*
    @length = 0
    @capacity = capacity
  end

  def self.build(capacity = 64)
    buffer = new(capacity)
    yield buffer
    buffer.to_s
  end

  def buffer
    @buffer
  end

  def write_byte(byte : UInt8)
    check_needs_resize
    @buffer[@length] = byte
    @length += 1
  end

  def <<(char : Char)
    char.each_byte { |byte| write_byte byte }
  end

  def <<(string : String)
    append string.cstr, string.length
  end

  def <<(obj)
    self << obj.to_s
  end

  def write(buffer : UInt8*, count)
    append buffer, count
  end

  def append(buffer : UInt8*, count)
    make_room_for count

    (@buffer + @length).memcpy(buffer, count)
    @length += count

    self
  end

  def make_room_for(n_bytes : Int)
    new_length = length + n_bytes
    if new_length > @capacity
      cap2 = Math.log2(new_length).ceil
      new_capacity = 2 ** cap2
      resize_to_capacity(new_capacity)
    end
  end

  def clear
    @length = 0
  end

  def length
    @length
  end

  def empty?
    @length == 0
  end

  def to_s
    String.new @buffer, @length
  end

  def to_s(io)
    io.append @buffer, @length
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
