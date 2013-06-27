class Int16
  MIN = -32768_i16
  MAX =  32767_i16

  def ==(other)
    false
  end

  def -@
    0_i16 - self
  end

  def to_s
    String.new_with_capacity(7) do |buffer|
      C.sprintf(buffer, "%hd", self)
    end
  end
end