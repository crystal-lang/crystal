struct Float
  def self.zero
    cast(0)
  end

  def +
    self
  end

  def nan?
    !(self == self)
  end

  macro def infinite? : Int32?
    if nan? || self == 0 || self != 2 * self
      nil
    else
      self > 0 ? 1 : -1
    end
  end

  def finite?
    !nan? && !infinite?
  end
end

struct Float32
  NAN = 0_f32 / 0_f32
  INFINITY = 1_f32 / 0_f32
  MIN = -INFINITY
  MAX =  INFINITY

  def -
    0.0_f32 - self
  end

  def ceil
    LibM.ceil_f32(self)
  end

  def floor
    LibM.floor_f32(self)
  end

  def round
    LibM.round_f32(self)
  end

  def trunc
    LibM.trunc_f32(self)
  end

  def **(other : Int32)
    LibM.powi_f32(self, other)
  end

  def **(other : Float32)
    LibM.pow_f32(self, other)
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

  def hash
    n = self
    (pointerof(n) as Int32*).value
  end

  def self.cast(value)
    value.to_f32
  end
end

struct Float64
  NAN = 0_f64 / 0_f64
  INFINITY = 1_f64 / 0_f64
  MIN = -INFINITY
  MAX =  INFINITY

  def -
    0.0 - self
  end

  def ceil
    LibM.ceil_f64(self)
  end

  def floor
    LibM.floor_f64(self)
  end

  def round
    LibM.round_f64(self)
  end

  def trunc
    LibM.trunc_f64(self)
  end

  def **(other : Int32)
    LibM.powi_f64(self, other)
  end

  def **(other : Float64)
    LibM.pow_f64(self, other)
  end

  def **(other)
    self ** other.to_f64
  end

  def to_s
    String.new(22) do |buffer|
      C.sprintf(buffer, "%g", self)
      len = C.strlen(buffer)
      {len, len}
    end
  end

  def to_s(io : IO)
    chars = StaticArray(UInt8, 22).new(0_u8)
    C.sprintf(chars, "%g", self)
    io.write(chars.to_slice, C.strlen(chars.buffer))
  end

  def hash
    n = self
    (pointerof(n) as Int64*).value
  end

  def self.cast(value)
    value.to_f64
  end
end
