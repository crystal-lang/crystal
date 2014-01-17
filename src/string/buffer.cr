class String::Buffer
  def initialize(capacity = 64)
    @buffer = Pointer(UInt8).malloc(capacity)
    @length = 0
    @capacity = capacity
  end

  def buffer
    @buffer
  end

  def <<(c : Char)
    c = c.ord
    if c <= 0x7f
      # 0xxxxxxx
      append_byte(c.to_u8)
    elsif c <= 0x7ff
      # 110xxxxx  10xxxxxx
      append_byte((0xc0 | c >> 6).to_u8)
      append_byte((0x80 | c & 0x3f).to_u8)
    elsif c <= 0xffff
      # 1110xxxx  10xxxxxx  10xxxxxx
      append_byte((0xe0 | c >> 12).to_u8)
      append_byte((0x80 | c >> 6 & 0x3f).to_u8)
      append_byte((0x80 | c & 0x3f).to_u8)
    elsif c <= 0x1fffff
      # 11110xxx  10xxxxxx  10xxxxxx  10xxxxxx
      append_byte((0xf0 | c >> 18).to_u8)
      append_byte((0x80 | c >> 12 & 0x3f).to_u8)
      append_byte((0x80 | c >> 6 & 0x3f).to_u8)
      append_byte((0x80 | c & 0x3f).to_u8)
    else
      raise "Invalid char value"
    end
  end

  def <<(obj : String)
    append obj.cstr, obj.length
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

  def append_byte(byte : UInt8)
    check_needs_resize
    @buffer[@length] = byte
    @length += 1
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
