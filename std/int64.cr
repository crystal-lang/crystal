class Int64
  MIN = -9223372036854775808_i64
  MAX =  9223372036854775807_i64

  def ==(other)
    false
  end

  def -@
    0_i64 - self
  end

  def to_s
    String.new_with_capacity(22) do |buffer|
      C.sprintf(buffer, "%ld", self)
    end
  end
end