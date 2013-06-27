class Int32
  MIN = -2147483648_i32
  MAX =  2147483647_i32

  def ==(other)
    false
  end

  def -@
    0 - self
  end

  def to_s
    String.new_with_capacity(12) do |buffer|
      C.sprintf(buffer, "%d", self)
    end
  end
end
