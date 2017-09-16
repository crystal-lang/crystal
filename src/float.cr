require "c/stdio"
require "c/string"
require "./float/printer"

# Float is the base type of all floating point numbers.
#
# There are two floating point types, `Float32` and `Float64`,
# which correspond to the [binary32](http://en.wikipedia.org/wiki/Single_precision_floating-point_format)
# and [binary64](http://en.wikipedia.org/wiki/Double_precision_floating-point_format)
# types defined by IEEE.
#
# A floating point literal is an optional `+` or `-` sign, followed by
# a sequence of numbers or underscores, followed by a dot,
# followed by numbers or underscores, followed by an optional exponent suffix,
# followed by an optional type suffix. If no suffix is present, the literal's type is `Float64`.
#
# ```
# 1.0     # Float64
# 1.0_f32 # Float32
# 1_f32   # Float32
#
# 1e10   # Float64
# 1.5e10 # Float64
# 1.5e-7 # Float64
#
# +1.3 # Float64
# -0.5 # Float64
# ```
#
# The underscore `_` before the suffix is optional.
#
# Underscores can be used to make some numbers more readable:
#
# ```
# 1_000_000.111_111 # better than 1000000.111111
# ```
struct Float
  alias Primitive = Float32 | Float64

  def -
    self.class.zero - self
  end

  def %(other)
    modulo(other)
  end

  def nan?
    !(self == self)
  end

  def infinite?
    if nan? || self == 0 || self != 2 * self
      nil
    else
      self > 0 ? 1 : -1
    end
  end

  def finite?
    !nan? && !infinite?
  end

  def fdiv(other)
    self / other
  end

  def modulo(other)
    if other == 0.0
      raise DivisionByZero.new
    else
      self - other * self.fdiv(other).floor
    end
  end

  def remainder(other)
    if other == 0.0
      raise DivisionByZero.new
    else
      mod = self % other
      return self.class.zero if mod == 0.0
      return mod if self > 0 && other > 0
      return mod if self < 0 && other < 0

      mod - other
    end
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.float(self)
  end

  # Writes this float to the given *io* in the given *format*.
  # See also: `IO#write_bytes`.
  def to_io(io : IO, format : IO::ByteFormat)
    format.encode(self, io)
  end

  # Reads a float from the given *io* in the given *format*.
  # See also: `IO#read_bytes`.
  def self.from_io(io : IO, format : IO::ByteFormat) : self
    format.decode(self, io)
  end
end

struct Float32
  NAN      = (0_f32 / 0_f32).as Float32
  INFINITY = (1_f32 / 0_f32).as Float32
  MIN      = (-INFINITY).as Float32
  MAX      = INFINITY.as Float32

  # Returns a `Float32` by invoking `to_f32` on *value*.
  def self.new(value)
    value.to_f32
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
    String.build(22) do |buffer|
      Printer.print(self, buffer)
    end
  end

  def to_s(io : IO)
    Printer.print(self, io)
  end

  def inspect(io)
    to_s(io)
    io << "_f32"
  end

  def clone
    self
  end
end

struct Float64
  NAN      = (0_f64 / 0_f64).as Float64
  INFINITY = (1_f64 / 0_f64).as Float64
  MIN      = (-INFINITY).as Float64
  MAX      = INFINITY.as Float64

  # Returns a `Float64` by invoking `to_f64` on *value*.
  def Float64.new(value)
    value.to_f64
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
    String.build(22) do |buffer|
      Printer.print(self, buffer)
    end
  end

  def to_s(io : IO)
    Printer.print(self, io)
  end

  def clone
    self
  end
end
