class String::Buffer
  def initialize(capacity = 64)
    @buffer = Pointer(Char).malloc(capacity)
    @length = 0
    @capacity = capacity
  end

  def buffer
    @buffer
  end

  def <<(c : Char)
    check_needs_resize
    @buffer[@length] = c
    @length += 1
    self
  end

  def <<(obj : String)
    obj_length = obj.length
    new_length = length + obj_length
    if new_length > @capacity
      cap2 = Math.log2(new_length).ceil
      new_capacity = 2 ** cap2
      resize_to_capacity(new_capacity)
    end

    (@buffer + @length).memcpy(obj.cstr, obj_length)
    @length += obj_length

    self
  end

  def <<(obj)
    self << obj.to_s
  end

  def clear
    @length = 0
  end

  def length
    @length
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
