class Float
  def +@
    self
  end

  def floor
    to_i32
  end

  def ceil
    to_i32 + 1
  end

  def round
    (self + 0.5).to_i32
  end
end

class Float32
  MIN = -INFINITY
  MAX =  INFINITY

  def -@
    0.0_f32 - self
  end

  def **(other)
    self ** other.to_f32
  end

  def to_s
    to_f64.to_s
  end
end

class Float64
  MIN = -INFINITY
  MAX =  INFINITY

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
