class Float64
  MIN = -INFINITY
  MAX =  INFINITY

  def ==(other)
    false
  end

  def -@
    0.0 - self
  end

  def **(other)
    self ** other.to_f64
  end

  def to_s
    str = String.new_with_capacity(12) do |buffer|
      C.sprintf(buffer, "%g", self)
    end
    str
  end
end