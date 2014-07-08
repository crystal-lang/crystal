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

  def <<(byte : UInt8)
    check_needs_resize
    @buffer[@length] = byte
    @length += 1
  end

  def <<(char : Char)
    char.each_byte { |byte| self << byte }
  end

  def <<(string : String)
    append string.cstr, string.length
  end

  def <<(obj)
    self << obj.to_s
  end

  def append(buffer : UInt8*, obj_length)
    new_length = length + obj_length
    if new_length > @capacity
      cap2 = Math.log2(new_length).ceil
      new_capacity = 2 ** cap2
      resize_to_capacity(new_capacity)
    end

    (@buffer + @length).memcpy(buffer, obj_length)
    @length += obj_length

    self
  end

  def append_c_string(buffer : UInt8*)
    append buffer, C.strlen(buffer)
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
    String.new @buffer, length
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
