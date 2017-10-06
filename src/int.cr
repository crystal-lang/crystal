# Int is the base type of all integer types.
#
# There are four signed integer types: `Int8`, `Int16`, `Int32` and `Int64`,
# being able to represent numbers of 8, 16, 32 and 64 bits respectively.
# There are four unsigned integer types: `UInt8`, `UInt16`, `UInt32` and `UInt64`.
#
# An integer literal is an optional `+` or `-` sign, followed by
# a sequence of digits and underscores, optionally followed by a suffix.
# If no suffix is present, the literal's type is the lowest between `Int32`, `Int64` and `UInt64`
# in which the number fits:
#
# ```
# 1 # Int32
#
# 1_i8  # Int8
# 1_i16 # Int16
# 1_i32 # Int32
# 1_i64 # Int64
#
# 1_u8  # UInt8
# 1_u16 # UInt16
# 1_u32 # UInt32
# 1_u64 # UInt64
#
# +10 # Int32
# -20 # Int32
#
# 2147483648          # Int64
# 9223372036854775808 # UInt64
# ```
#
# The underscore `_` before the suffix is optional.
#
# Underscores can be used to make some numbers more readable:
#
# ```
# 1_000_000 # better than 1000000
# ```
#
# Binary numbers start with `0b`:
#
# ```
# 0b1101 # == 13
# ```
#
# Octal numbers start with `0o`:
#
# ```
# 0o123 # == 83
# ```
#
# Hexadecimal numbers start with `0x`:
#
# ```
# 0xFE012D # == 16646445
# 0xfe012d # == 16646445
# ```
struct Int
  alias Signed = Int8 | Int16 | Int32 | Int64 | Int128
  alias Unsigned = UInt8 | UInt16 | UInt32 | UInt64 | UInt128
  alias Primitive = Signed | Unsigned

  # Returns a `Char` that has the unicode codepoint of `self`.
  #
  # Raises `ArgumentError` if this integer's value doesn't fit a char's range (`0..0x10ffff`).
  #
  # ```
  # 97.chr # => 'a'
  # ```
  def chr
    unless 0 <= self <= Char::MAX_CODEPOINT
      raise ArgumentError.new("#{self} out of char range")
    end
    unsafe_chr
  end

  def ~
    self ^ -1
  end

  # Divides `self` by *other* using floored division.
  #
  # In floored division, given two integers x and y:
  # * q = x / y is rounded toward negative infinity
  # * r = x % y has the sign of the second argument
  # * x == q*y + r
  #
  # For example:
  #
  # ```text
  #  x     y     x / y     x % y
  #  5     3       1         2
  # -5     3      -2         1
  #  5    -3      -2        -1
  # -5    -3       1        -2
  # ```
  #
  # Raises if *other* is zero, or if *other* is -1 and
  # `self` is signed and is the minimum value for that
  # integer type.
  def /(other : Int)
    check_div_argument other

    div = unsafe_div other
    mod = unsafe_mod other
    div -= 1 if other > 0 ? mod < 0 : mod > 0
    div
  end

  # Divides `self` by *other* using truncated division.
  #
  # In truncated division, given two integers x and y:
  # * `q = x.tdiv(y)` is rounded toward zero
  # * `r = x.remainder(y)` has the sign of the first argument
  # * `x == q*y + r`
  #
  # For example:
  #
  # ```text
  #  x     y     x / y     x % y
  #  5     3       1         2
  # -5     3      -1        -2
  #  5    -3      -1         2
  # -5    -3       1        -2
  # ```
  #
  # Raises if *other* is `0`, or if *other* is `-1` and
  # `self` is signed and is the minimum value for that
  # integer type.
  def tdiv(other : Int)
    check_div_argument other

    unsafe_div other
  end

  private def check_div_argument(other)
    if other == 0
      raise DivisionByZero.new
    end

    {% begin %}
      if self < 0 && self == {{@type}}::MIN && other == -1
        raise ArgumentError.new "Overflow: {{@type}}::MIN / -1"
      end
    {% end %}
  end

  def fdiv(other)
    to_f / other
  end

  # Returns `self` modulo *other*.
  #
  # This uses floored division.
  #
  # See `Int#/` for more details.
  def %(other : Int)
    if other == 0
      raise DivisionByZero.new
    elsif (self ^ other) >= 0
      self.unsafe_mod(other)
    else
      me = self.unsafe_mod(other)
      me == 0 ? me : me + other
    end
  end

  # Returns `self` remainder *other*.
  #
  # This uses truncated division.
  #
  # See `Int#div` for more details.
  def remainder(other : Int)
    if other == 0
      raise DivisionByZero.new
    else
      unsafe_mod other
    end
  end

  # Returns the result of shifting this number's bits *count* positions to the right.
  # Also known as arithmetic right shift.
  #
  # * If *count* is greater than the number of bits of this integer, returns 0
  # * If *count* is negative, a left shift is performed
  #
  # ```
  # 8000 >> 1  # => 4000
  # 8000 >> 2  # => 2000
  # 8000 >> 32 # => 0
  # 8000 >> -1 # => 16000
  #
  # -8000 >> 1 # => -4000
  # ```
  def >>(count : Int)
    if count < 0
      self << count.abs
    elsif count < sizeof(self) * 8
      self.unsafe_shr(count)
    else
      self.class.zero
    end
  end

  # Returns the result of shifting this number's bits *count* positions to the left.
  #
  # * If *count* is greater than the number of bits of this integer, returns 0
  # * If *count* is negative, a right shift is performed
  #
  # ```
  # 8000 << 1  # => 16000
  # 8000 << 2  # => 32000
  # 8000 << 32 # => 0
  # 8000 << -1 # => 4000
  # ```
  def <<(count : Int)
    if count < 0
      self >> count.abs
    elsif count < sizeof(self) * 8
      self.unsafe_shl(count)
    else
      self.class.zero
    end
  end

  def abs
    self >= 0 ? self : -self
  end

  def ceil
    self
  end

  def floor
    self
  end

  def round
    self
  end

  def trunc
    self
  end

  # Returns the value of raising `self` to the power of *exponent*.
  #
  # Raises `ArgumentError` if *exponent* is negative: if this is needed,
  # either use a float base or a float exponent.
  #
  # ```
  # 2 ** 3  # => 8
  # 2 ** 0  # => 1
  # 2 ** -1 # ArgumentError
  # ```
  def **(exponent : Int) : self
    if exponent < 0
      raise ArgumentError.new "Cannot raise an integer to a negative integer power, use floats for that"
    end

    result = self.class.new(1)
    k = self
    while exponent > 0
      result *= k if exponent & 0b1 != 0
      k *= k
      exponent = exponent.unsafe_shr(1)
    end
    result
  end

  # Returns the value of raising `self` to the power of *exponent*.
  #
  # ```
  # 2 ** 3.0  # => 8.0
  # 2 ** 0.0  # => 1.0
  # 2 ** -1.0 # => 0.5
  # ```
  def **(exponent : Float) : Float64
    to_f ** exponent
  end

  def ===(char : Char)
    self === char.ord
  end

  # Returns this number's *bit*th bit, starting with the least-significant.
  #
  # ```
  # 11.bit(0) # => 1
  # 11.bit(1) # => 1
  # 11.bit(2) # => 0
  # 11.bit(3) # => 1
  # 11.bit(4) # => 0
  # ```
  def bit(bit)
    self >> bit & 1
  end

  def gcd(other : Int)
    self == 0 ? other.abs : (other % self).gcd(self)
  end

  def lcm(other : Int)
    (self * other).abs / gcd(other)
  end

  def divisible_by?(num)
    self % num == 0
  end

  def even?
    divisible_by? 2
  end

  def odd?
    !even?
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.int(self)
  end

  def succ
    self + 1
  end

  def pred
    self - 1
  end

  def times(&block : self ->) : Nil
    i = self ^ self
    while i < self
      yield i
      i += 1
    end
  end

  def times
    TimesIterator(typeof(self)).new(self)
  end

  def upto(to, &block : self ->) : Nil
    x = self
    while x <= to
      yield x
      x += 1
    end
  end

  def upto(to)
    UptoIterator(typeof(self), typeof(to)).new(self, to)
  end

  def downto(to, &block : self ->) : Nil
    x = self
    while x >= to
      yield x
      x -= 1
    end
  end

  def downto(to)
    DowntoIterator(typeof(self), typeof(to)).new(self, to)
  end

  def to(to, &block : self ->) : Nil
    if self < to
      upto(to) { |i| yield i }
    elsif self > to
      downto(to) { |i| yield i }
    else
      yield self
    end
  end

  def to(to)
    self <= to ? upto(to) : downto(to)
  end

  def modulo(other)
    self % other
  end

  private DIGITS_DOWNCASE = "0123456789abcdefghijklmnopqrstuvwxyz"
  private DIGITS_UPCASE   = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  private DIGITS_BASE62   = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  def to_s
    to_s(10)
  end

  def to_s(io : IO)
    to_s(10, io)
  end

  def to_s(base : Int, upcase : Bool = false)
    raise ArgumentError.new("Invalid base #{base}") unless 2 <= base <= 36 || base == 62
    raise ArgumentError.new("upcase must be false for base 62") if upcase && base == 62

    case self
    when 0
      return "0"
    when 1
      return "1"
    end

    internal_to_s(base, upcase) do |ptr, count|
      String.new(ptr, count, count)
    end
  end

  def to_s(base : Int, io : IO, upcase : Bool = false)
    raise ArgumentError.new("Invalid base #{base}") unless 2 <= base <= 36 || base == 62
    raise ArgumentError.new("upcase must be false for base 62") if upcase && base == 62

    case self
    when 0
      io << '0'
      return
    when 1
      io << '1'
      return
    end

    internal_to_s(base, upcase) do |ptr, count|
      io.write_utf8 Slice.new(ptr, count)
    end
  end

  private def internal_to_s(base, upcase = false)
    # Given sizeof(self) <= 128 bits, we need at most 128 bytes for a base 2
    # representation, plus one byte for the trailing 0.
    chars = uninitialized UInt8[129]
    ptr_end = chars.to_unsafe + 128
    ptr = ptr_end
    num = self

    neg = num < 0

    digits = (base == 62 ? DIGITS_BASE62 : (upcase ? DIGITS_UPCASE : DIGITS_DOWNCASE)).to_unsafe

    while num != 0
      ptr -= 1
      ptr.value = digits[num.remainder(base).abs]
      num = num.tdiv(base)
    end

    if neg
      ptr -= 1
      ptr.value = '-'.ord.to_u8
    end

    count = (ptr_end - ptr).to_i32
    yield ptr, count
  end

  def inspect(io)
    type = case self
           when Int8    then "_i8"
           when Int16   then "_i16"
           when Int32   then ""
           when Int64   then "_i64"
           when Int128  then "_i128"
           when UInt8   then "_u8"
           when UInt16  then "_u16"
           when UInt32  then "_u32"
           when UInt64  then "_u64"
           when UInt128 then "_u128"
           else              raise "BUG: impossible"
           end

    to_s(io)
    io << type
  end

  # Writes this integer to the given *io* in the given *format*.
  #
  # See also: `IO#write_bytes`.
  def to_io(io : IO, format : IO::ByteFormat)
    format.encode(self, io)
  end

  # Reads an integer from the given *io* in the given *format*.
  #
  # See also: `IO#read_bytes`.
  def self.from_io(io : IO, format : IO::ByteFormat) : self
    format.decode(self, io)
  end

  # Counts `1`-bits in the binary representation of this integer.
  #
  # ```
  # 5.popcount   # => 2
  # -15.popcount # => 29
  # ```
  abstract def popcount

  private class TimesIterator(T)
    include Iterator(T)

    @n : T
    @index : T

    def initialize(@n : T, @index = T.zero)
    end

    def next
      if @index < @n
        value = @index
        @index += 1
        value
      else
        stop
      end
    end

    def rewind
      @index = T.zero
      self
    end
  end

  private class UptoIterator(T, N)
    include Iterator(T)

    @from : T
    @to : N
    @current : T

    def initialize(@from : T, @to : N)
      @current = @from
    end

    def next
      if @current > @to
        stop
      else
        value = @current
        @current += 1
        value
      end
    end

    def rewind
      @current = @from
      self
    end
  end

  private class DowntoIterator(T, N)
    include Iterator(T)

    @from : T
    @to : N
    @current : T

    def initialize(@from : T, @to : N)
      @current = @from
    end

    def next
      if @current < @to
        stop
      else
        value = @current
        @current -= 1
        value
      end
    end

    def rewind
      @current = @from
      self
    end
  end
end

struct Int8
  MIN = -128_i8
  MAX =  127_i8

  # Returns an `Int8` by invoking `to_i8` on *value*.
  def self.new(value)
    value.to_i8
  end

  def -
    0_i8 - self
  end

  def popcount
    Intrinsics.popcount8(self)
  end

  def clone
    self
  end
end

struct Int16
  MIN = -32768_i16
  MAX =  32767_i16

  # Returns an `Int16` by invoking `to_i16` on *value*.
  def self.new(value)
    value.to_i16
  end

  def -
    0_i16 - self
  end

  def popcount
    Intrinsics.popcount16(self)
  end

  def clone
    self
  end
end

struct Int32
  MIN = -2147483648_i32
  MAX =  2147483647_i32

  # Returns an `Int32` by invoking `to_i32` on *value*.
  def self.new(value)
    value.to_i32
  end

  def -
    0 - self
  end

  def popcount
    Intrinsics.popcount32(self)
  end

  def clone
    self
  end
end

struct Int64
  MIN = -9223372036854775808_i64
  MAX =  9223372036854775807_i64

  # Returns an `Int64` by invoking `to_i64` on *value*.
  def self.new(value)
    value.to_i64
  end

  def -
    0_i64 - self
  end

  def popcount
    Intrinsics.popcount64(self)
  end

  def clone
    self
  end
end

struct Int128
  # TODO: eventually update to literals once UInt128 bit support is finished
  MIN = new(1) << 127
  MAX = ~MIN

  # Returns an `Int128` by invoking `to_i128` on *value*.
  def self.new(value)
    value.to_i128
  end

  def -
    # TODO: use 0_i128 - self
    Int128.new(0) - self
  end

  def popcount
    # TODO: use after Crystal 0.23.1
    # Intrinsics.popcount128(self)
    v1, v2 = self.unsafe_as({Int64, Int64})
    Int128.new(v1.popcount + v2.popcount)
  end

  def clone
    self
  end
end

struct UInt8
  MIN =   0_u8
  MAX = 255_u8

  # Returns an `UInt8` by invoking `to_u8` on *value*.
  def self.new(value)
    value.to_u8
  end

  def abs
    self
  end

  def popcount
    Intrinsics.popcount8(self)
  end

  def clone
    self
  end
end

struct UInt16
  MIN =     0_u16
  MAX = 65535_u16

  # Returns an `UInt16` by invoking `to_u16` on *value*.
  def self.new(value)
    value.to_u16
  end

  def abs
    self
  end

  def popcount
    Intrinsics.popcount16(self)
  end

  def clone
    self
  end
end

struct UInt32
  MIN =          0_u32
  MAX = 4294967295_u32

  # Returns an `UInt32` by invoking `to_u32` on *value*.
  def self.new(value)
    value.to_u32
  end

  def abs
    self
  end

  def popcount
    Intrinsics.popcount32(self)
  end

  def clone
    self
  end
end

struct UInt64
  MIN =                    0_u64
  MAX = 18446744073709551615_u64

  # Returns an `UInt64` by invoking `to_u64` on *value*.
  def self.new(value)
    value.to_u64
  end

  def abs
    self
  end

  def popcount
    Intrinsics.popcount64(self)
  end

  def clone
    self
  end
end

struct UInt128
  # TODO: eventually update to literals once UInt128 bit support is finished
  MIN = new 0
  MAX = ~MIN

  # Returns an `UInt128` by invoking `to_u128` on *value*.
  def self.new(value)
    value.to_u128
  end

  def abs
    self
  end

  def popcount
    # TODO: use after Crystal 0.23.1
    # Intrinsics.popcount128(self)
    v1, v2 = self.unsafe_as({UInt64, UInt64})
    UInt128.new(v1.popcount + v2.popcount)
  end

  def clone
    self
  end
end
