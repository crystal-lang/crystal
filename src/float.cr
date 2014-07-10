struct Float
  def +
    self
  end

  def floor
    to_i32
  end

  def round
    (self + 0.5).to_i32
  end
end

struct Float32
  MIN = -INFINITY
  MAX =  INFINITY

  def -
    0.0_f32 - self
  end

  def ceil
    Intrinsics.ceil_f32(self).to_i
  end

  def **(other : Float32)
    Intrinsics.pow_f32(self, other)
  end

  def **(other)
    self ** other.to_f32
  end

  def to_s
    to_f64.to_s
  end

  def to_s(io : IO)
    to_f64.to_s(io)
  end
end

struct Float64
  MIN = -INFINITY
  MAX =  INFINITY

  def -
    0.0 - self
  end

  def ceil
    Intrinsics.ceil_f64(self).to_i
  end

  def **(other : Float64)
    Intrinsics.pow_f64(self, other)
  end

  def **(other)
    self ** other.to_f64
  end

  def to_s
    String.new_with_capacity(22) do |buffer|
      C.sprintf(buffer, "%g", self)
    end
  end

  def to_s(io : IO)
    chars :: UInt8[22]
    chars.set_all_to 0_u8
    C.sprintf(chars.buffer, "%g", self)
    io.write(chars.buffer, C.strlen(chars.buffer))
  end
end
