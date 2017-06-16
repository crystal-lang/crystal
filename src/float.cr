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

  private HASH_NAN      =      0
  private HASH_INFINITY = 314159

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

  def hash
    return HASH_NAN if nan?
    if infinite?
      return self > 0 ? +HASH_INFINITY : -HASH_INFINITY
    end
    frac, exp = Math.frexp self
    frac.unsafe_as(Int32) ^ ~exp
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

  private HASH_BITS     = 31 # sizeof(Hashing::Type) >= 8 ? 61 : 31
  private HASH_MODULUS  = (1 << HASH_BITS) - 1
  private U32_MINUS_ONE = -1.unsafe_as(UInt32)
  private U32_MINUS_TWO = -2.unsafe_as(UInt32)

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

  # For numeric types, the hash of a number x is based on the reduction
  # of x modulo the prime P = 2**HASH_BITS - 1.  It's designed so that
  # hash(x) == hash(y) whenever x and y are numerically equal, even if
  # x and y have different types.
  # A quick summary of the hashing strategy:
  # (1) First define the 'reduction of x modulo P' for any rational
  # number x; this is a standard extension of the usual notion of
  # reduction modulo P for integers.  If x == p/q (written in lowest
  # terms), the reduction is interpreted as the reduction of p times
  # the inverse of the reduction of q, all modulo P; if q is exactly
  # divisible by P then define the reduction to be infinity.  So we've
  # got a well-defined map
  #   reduce : { rational numbers } -> { 0, 1, 2, ..., P-1, infinity }.
  # (2) Now for a rational number x, define hash(x) by:
  #   reduce(x)   if x >= 0
  #   -reduce(-x) if x < 0
  # If the result of the reduction is infinity (this is impossible for
  # integers, floats and Decimals) then use the predefined hash value
  # HASH_INF for x >= 0, or -HASH_INF for x < 0, instead.
  # HASH_INF, -HASH_INF and HASH_NAN are also used for the
  # hashes of float and Decimal infinities and nans.
  # A selling point for the above strategy is that it makes it possible
  # to compute hashes of decimal and binary floating-point numbers
  # efficiently, even if the exponent of the binary or decimal number
  # is large.  The key point is that
  #   reduce(x * y) == reduce(x) * reduce(y) (modulo HASH_MODULUS)
  # provided that {reduce(x), reduce(y)} != {0, infinity}.  The reduction of a
  # binary or decimal float is never infinity, since the denominator is a power
  # of 2 (for binary) or a divisor of a power of 10 (for decimal).  So we have,
  # for nonnegative x,
  #   reduce(x * 2**e) == reduce(x) * reduce(2**e) % _PyHASH_MODULUS
  #   reduce(x * 10**e) == reduce(x) * reduce(10**e) % _PyHASH_MODULUS
  # and reduce(10**e) can be computed efficiently by the usual modular
  # exponentiation algorithm.  For reduce(2**e) it's even better: since
  # P is of the form 2**n-1, reduce(2**e) is 2**(e mod n), and multiplication
  # by 2**(e mod n) modulo 2**n-1 just amounts to a rotation of bits.
  def hash
    return HASH_NAN if nan?
    if infinite?
      return self > 0 ? +HASH_INFINITY : -HASH_INFINITY
    end
    frac, exp = Math.frexp self
    sign = 1u32
    if self < 0
      sign = U32_MINUS_ONE
      frac = -frac
    end
    # process 28 bits at a time;  this should work well both for binary
    # and hexadecimal floating point.
    x = 0u32
    while frac > 0
      x = ((x << 28) & HASH_MODULUS) | x >> (HASH_BITS - 28)
      frac *= 268435456.0 # 2**28
      exp -= 28
      y = frac.to_u32 # pull out integer part
      frac -= y
      x += y
      x -= HASH_MODULUS if x >= HASH_MODULUS
    end
    # adjust for the exponent;  first reduce it modulo HASH_BITS
    exp = exp >= 0 ? exp % HASH_BITS : HASH_BITS - 1 - ((-1 - exp) % HASH_BITS)
    x = ((x << exp) & HASH_MODULUS) | x >> (HASH_BITS - exp)

    x = x * sign
    x = U32_MINUS_TWO if x == U32_MINUS_ONE
    x.unsafe_as(Int32)
  end

  def clone
    self
  end
end
