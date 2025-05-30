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
#
# See [`Float` literals](https://crystal-lang.org/reference/syntax_and_semantics/literals/floats.html) in the language reference.
struct Float
  alias Primitive = Float32 | Float64

  def -
    self.class.zero - self
  end

  def //(other)
    self.fdiv(other).floor
  end

  def %(other)
    modulo(other)
  end

  # Returns whether this value is a not-a-number.
  #
  # This includes both quiet and signalling NaNs from IEEE 754.
  def nan? : Bool
    !(self == self)
  end

  # Checks whether this value is infinite. Returns `1` if this value is positive
  # infinity, `-1` if this value is negative infinity, or `nil` otherwise.
  def infinite? : Int32?
    # fallback implementation
    # TODO: consider using https://llvm.org/docs/LangRef.html#llvm-is-fpclass-intrinsic
    if nan? || self == 0 || self != 2 * self
      nil
    else
      self > 0 ? 1 : -1
    end
  end

  # Returns whether this value is finite, i.e. it is neither infinite nor a
  # not-a-number.
  def finite? : Bool
    !nan? && !infinite?
  end

  def modulo(other)
    if other == 0.0
      raise DivisionByZeroError.new
    else
      self - other * (self // other)
    end
  end

  def remainder(other)
    if other == 0.0
      raise DivisionByZeroError.new
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
  def to_io(io : IO, format : IO::ByteFormat) : Nil
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
  # Smallest finite value
  MIN = -3.40282347e+38_f32
  # Largest finite value
  MAX = 3.40282347e+38_f32
  # The machine epsilon (difference between 1.0 and the next representable value)
  EPSILON = 1.19209290e-07_f32
  # The number of decimal digits that can be represented without losing precision
  DIGITS = 6
  # The radix or integer base used by the internal representation
  RADIX = 2
  # The number of digits that can be represented without losing precision (in base RADIX)
  MANT_DIGITS = 24
  # The minimum possible normal power of 2 exponent
  MIN_EXP = -125
  # The maximum possible normal power of 2 exponent
  MAX_EXP = 128
  # The minimum possible power of 10 exponent (such that 10**MIN_10_EXP is representable)
  MIN_10_EXP = -37
  # The maximum possible power of 10 exponent (such that 10**MAX_10_EXP is representable)
  MAX_10_EXP = 38
  # Smallest normal positive value, whose previous representable value is subnormal
  MIN_POSITIVE = 1.17549435e-38_f32
  # Smallest representable positive value, whose previous representable value is zero
  MIN_SUBNORMAL = 1.0e-45_f32

  # Returns a `Float32` by invoking `String#to_f32` on *value*.
  #
  # ```
  # Float32.new "20"                        # => 20.0
  # Float32.new "  20  ", whitespace: false # raises ArgumentError: Invalid Float32: "  20  "
  # ```
  def self.new(value : String, whitespace : Bool = true, strict : Bool = true) : self
    value.to_f32 whitespace: whitespace, strict: strict
  end

  # Returns a `Float32` by invoking `to_f32` on *value*.
  def self.new(value)
    value.to_f32
  end

  # Returns a `Float32` by invoking `to_f32!` on *value*.
  def self.new!(value) : self
    value.to_f32!
  end

  # Returns a `Float32` by parsing *str* as a hexadecimal-significand string, or
  # `nil` if parsing fails.
  #
  # The string format is defined in section 5.12.3 of IEEE 754-2008, and is the
  # same as the `%a` specifier for `sprintf`. Unlike e.g. `String#to_f`,
  # whitespace and underscores are not allowed. Non-finite values are also
  # recognized.
  #
  # ```
  # Float32.parse_hexfloat?("0x123.456p7")     # => 37282.6875_f32
  # Float32.parse_hexfloat?("0x1.fffffep+127") # => Float32::MAX
  # Float32.parse_hexfloat?("-inf")            # => -Float32::INFINITY
  # Float32.parse_hexfloat?("0x1")             # => nil
  # Float32.parse_hexfloat?("a.bp+3")          # => nil
  # ```
  def self.parse_hexfloat?(str : String) : self?
    Float::Printer::Hexfloat(self, UInt32).to_f(str) { nil }
  end

  # Returns a `Float32` by parsing *str* as a hexadecimal-significand string.
  #
  # The string format is defined in section 5.12.3 of IEEE 754-2008, and is the
  # same as the `%a` specifier for `sprintf`. Unlike e.g. `String#to_f`,
  # whitespace and underscores are not allowed. Non-finite values are also
  # recognized.
  #
  # Raises `ArgumentError` if *str* is not a valid hexadecimal-significand
  # string.
  #
  # ```
  # Float32.parse_hexfloat("0x123.456p7")     # => 37282.6875_f32
  # Float32.parse_hexfloat("0x1.fffffep+127") # => Float32::MAX
  # Float32.parse_hexfloat("-inf")            # => -Float32::INFINITY
  # Float32.parse_hexfloat("0x1")             # Invalid hexfloat: expected 'p' or 'P' (ArgumentError)
  # Float32.parse_hexfloat("a.bp+3")          # Invalid hexfloat: expected '0' (ArgumentError)
  # ```
  def self.parse_hexfloat(str : String) : self
    Float::Printer::Hexfloat(self, UInt32).to_f(str) do |err|
      raise ArgumentError.new("Invalid hexfloat: #{err}")
    end
  end

  Number.expand_div [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128], Float32
  Number.expand_div [Float64], Float64

  # :inherit:
  def infinite? : Int32?
    # TODO: consider using https://llvm.org/docs/LangRef.html#llvm-is-fpclass-intrinsic
    case self
    when -Float32::INFINITY
      -1
    when Float32::INFINITY
      1
    end
  end

  def abs
    Math.copysign(self, 1)
  end

  # Returns `-1` if the sign bit of this float is set, `1` otherwise.
  #
  # Unlike `#sign`, this works on signed zeros and not-a-numbers as well.
  def sign_bit : Int32
    Math.copysign(1_f32, self).to_i
  end

  # Rounds towards positive infinity.
  def ceil : Float32
    LibM.ceil_f32(self)
  end

  # Rounds towards negative infinity.
  def floor : Float32
    LibM.floor_f32(self)
  end

  # Rounds towards the nearest integer. If both neighboring integers are equidistant,
  # rounds towards the even neighbor (Banker's rounding).
  def round_even : Float32
    # TODO: LLVM 11 introduced llvm.roundeven.* intrinsics which may replace
    # rint in the future.
    LibM.rint_f32(self)
  end

  # Rounds towards the nearest integer. If both neighboring integers are equidistant,
  # rounds away from zero.
  def round_away : Float32
    LibM.round_f32(self)
  end

  # Rounds towards zero.
  def trunc : Float32
    LibM.trunc_f32(self)
  end

  # Returns the least `Float32` that is greater than `self`.
  def next_float : Float32
    LibM.nextafter_f32(self, INFINITY)
  end

  # Returns the greatest `Float32` that is less than `self`.
  def prev_float : Float32
    LibM.nextafter_f32(self, -INFINITY)
  end

  def **(other : Int32)
    {% if flag?(:win32) %}
      self ** other.to_f32
    {% else %}
      LibM.powi_f32(self, other)
    {% end %}
  end

  def **(other : Float32) : Float32
    LibM.pow_f32(self, other)
  end

  def **(other) : Float32
    self ** other.to_f32
  end

  def to_s : String
    String.build(22) do |buffer|
      Printer.shortest(self, buffer)
    end
  end

  def to_s(io : IO) : Nil
    Printer.shortest(self, io)
  end

  # Returns the hexadecimal-significand representation of `self`.
  #
  # The string format is defined in section 5.12.3 of IEEE 754-2008, and is the
  # same as the `%a` specifier for `sprintf`. The integral part of the returned
  # string is `0` if `self` is subnormal, otherwise `1`. The fractional part
  # contains only significant digits.
  #
  # ```
  # 1234.0625_f32.to_hexfloat          # => "0x1.3484p+10"
  # Float32::MAX.to_hexfloat           # => "0x1.fffffep+127"
  # Float32::MIN_SUBNORMAL.to_hexfloat # => "0x0.000002p-126"
  # ```
  def to_hexfloat : String
    # the longest `Float64` strings are of the form `-0x1.234567p-127`
    String.build(16) do |buffer|
      Printer.hexfloat(self, buffer)
    end
  end

  # Writes `self`'s hexadecimal-significand representation to the given *io*.
  def to_hexfloat(io : IO) : Nil
    Printer.hexfloat(self, io)
  end

  def clone
    self
  end
end

struct Float64
  NAN      = (0_f64 / 0_f64).as Float64
  INFINITY = (1_f64 / 0_f64).as Float64

  # Smallest finite value
  MIN = -1.7976931348623157e+308_f64
  # Largest finite value
  MAX = 1.7976931348623157e+308_f64
  # The machine epsilon (difference between 1.0 and the next representable value)
  EPSILON = 2.2204460492503131e-16_f64
  # The number of decimal digits that can be represented without losing precision
  DIGITS = 15
  # The radix or integer base used by the internal representation
  RADIX = 2
  # The number of digits that can be represented without losing precision (in base RADIX)
  MANT_DIGITS = 53
  # The minimum possible normal power of 2 exponent
  MIN_EXP = -1021
  # The maximum possible normal power of 2 exponent
  MAX_EXP = 1024
  # The minimum possible power of 10 exponent (such that 10**MIN_10_EXP is representable)
  MIN_10_EXP = -307
  # The maximum possible power of 10 exponent (such that 10**MAX_10_EXP is representable)
  MAX_10_EXP = 308
  # Smallest normal positive value, whose previous representable value is subnormal
  MIN_POSITIVE = 2.2250738585072014e-308_f64
  # Smallest representable positive value, whose previous representable value is zero
  MIN_SUBNORMAL = 5.0e-324_f64

  # Returns a `Float64` by invoking `String#to_f64` on *value*.
  #
  # ```
  # Float64.new "20"                        # => 20.0
  # Float64.new "  20  ", whitespace: false # raises ArgumentError: Invalid Float64: "  20  "
  # ```
  def self.new(value : String, whitespace : Bool = true, strict : Bool = true) : self
    value.to_f64 whitespace: whitespace, strict: strict
  end

  # Returns a `Float64` by invoking `to_f64` on *value*.
  def Float64.new(value)
    value.to_f64
  end

  # Returns a `Float64` by invoking `to_f64!` on *value*.
  def Float64.new!(value) : Float64
    value.to_f64!
  end

  # Returns a `Float32` by parsing *str* as a hexadecimal-significand string, or
  # `nil` if parsing fails.
  #
  # The string format is defined in section 5.12.3 of IEEE 754-2008, and is the
  # same as the `%a` specifier for `sprintf`. Unlike e.g. `String#to_f`,
  # whitespace and underscores are not allowed. Non-finite values are also
  # recognized.
  #
  # ```
  # Float64.parse_hexfloat?("0x123.456p7")     # => 37282.6875
  # Float64.parse_hexfloat?("0x1.fffffep+127") # => Float64::MAX
  # Float64.parse_hexfloat?("-inf")            # => -Float64::INFINITY
  # Float64.parse_hexfloat?("0x1")             # => nil
  # Float64.parse_hexfloat?("a.bp+3")          # => nil
  # ```
  def self.parse_hexfloat?(str : String) : self?
    Float::Printer::Hexfloat(self, UInt64).to_f(str) { nil }
  end

  # Returns a `Float32` by parsing *str* as a hexadecimal-significand string.
  #
  # The string format is defined in section 5.12.3 of IEEE 754-2008, and is the
  # same as the `%a` specifier for `sprintf`. Unlike e.g. `String#to_f`,
  # whitespace and underscores are not allowed. Non-finite values are also
  # recognized.
  #
  # Raises `ArgumentError` if *str* is not a valid hexadecimal-significand
  # string.
  #
  # ```
  # Float64.parse_hexfloat("0x123.456p7")             # => 37282.6875
  # Float64.parse_hexfloat("0x1.fffffffffffffp+1023") # => Float64::MAX
  # Float64.parse_hexfloat("-inf")                    # => -Float64::INFINITY
  # Float64.parse_hexfloat("0x1")                     # Invalid hexfloat: expected 'p' or 'P' (ArgumentError)
  # Float64.parse_hexfloat("a.bp+3")                  # Invalid hexfloat: expected '0' (ArgumentError)
  # ```
  def self.parse_hexfloat(str : String) : self
    Float::Printer::Hexfloat(self, UInt64).to_f(str) do |err|
      raise ArgumentError.new("Invalid hexfloat: #{err}")
    end
  end

  Number.expand_div [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128], Float64
  Number.expand_div [Float32], Float64

  # :inherit:
  def infinite? : Int32?
    # TODO: consider using https://llvm.org/docs/LangRef.html#llvm-is-fpclass-intrinsic
    case self
    when -Float64::INFINITY
      -1
    when Float64::INFINITY
      1
    end
  end

  def abs
    Math.copysign(self, 1)
  end

  # Returns `-1` if the sign bit of this float is set, `1` otherwise.
  #
  # Unlike `#sign`, this works on signed zeros and not-a-numbers as well.
  def sign_bit : Int32
    Math.copysign(1_f64, self).to_i
  end

  def ceil : Float64
    LibM.ceil_f64(self)
  end

  def floor : Float64
    LibM.floor_f64(self)
  end

  # Rounds towards the nearest integer. If both neighboring integers are equidistant,
  # rounds towards the even neighbor (Banker's rounding).
  def round_even : Float64
    # TODO: LLVM 11 introduced llvm.roundeven.* intrinsics which may replace
    # rint in the future.
    LibM.rint_f64(self)
  end

  # Rounds towards the nearest integer. If both neighboring integers are equidistant,
  # rounds away from zero.
  def round_away : Float64
    LibM.round_f64(self)
  end

  def trunc : Float64
    LibM.trunc_f64(self)
  end

  # Returns the least `Float64` that is greater than `self`.
  def next_float : Float64
    LibM.nextafter_f64(self, INFINITY)
  end

  # Returns the greatest `Float64` that is less than `self`.
  def prev_float : Float64
    LibM.nextafter_f64(self, -INFINITY)
  end

  def **(other : Int32)
    {% if flag?(:win32) %}
      self ** other.to_f64
    {% else %}
      LibM.powi_f64(self, other)
    {% end %}
  end

  def **(other : Float64) : Float64
    LibM.pow_f64(self, other)
  end

  def **(other) : Float64
    self ** other.to_f64
  end

  def to_s : String
    # the longest `Float64` strings are of the form `-1.2345678901234567e+123`
    String.build(24) do |buffer|
      Printer.shortest(self, buffer)
    end
  end

  def to_s(io : IO) : Nil
    Printer.shortest(self, io)
  end

  # Returns the hexadecimal-significand representation of `self`.
  #
  # The string format is defined in section 5.12.3 of IEEE 754-2008, and is the
  # same as the `%a` specifier for `sprintf`. The integral part of the returned
  # string is `0` if `self` is subnormal, otherwise `1`. The fractional part
  # contains only significant digits.
  #
  # ```
  # 1234.0625.to_hexfloat              # => "0x1.3484p+10"
  # Float64::MAX.to_hexfloat           # => "0x1.fffffffffffffp+1023"
  # Float64::MIN_SUBNORMAL.to_hexfloat # => "0x0.0000000000001p-1022"
  # ```
  def to_hexfloat : String
    # the longest `Float64` strings are of the form `-0x1.23456789abcdep-1023`
    String.build(24) do |buffer|
      Printer.hexfloat(self, buffer)
    end
  end

  # Writes `self`'s hexadecimal-significand representation to the given *io*.
  def to_hexfloat(io : IO) : Nil
    Printer.hexfloat(self, io)
  end

  def clone
    self
  end
end
