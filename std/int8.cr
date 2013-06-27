class Int8
  MIN = -128_i8
  MAX =  127_i8

  def ==(other)
    false
  end

  def -@
    0_i8 - self
  end

  def to_s
    String.new_with_capacity(5) do |buffer|
      C.sprintf(buffer, "%hhd", self)
    end
  end
end