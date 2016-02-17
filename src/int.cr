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
  alias Signed = Int8 | Int16 | Int32 | Int64
  alias Unsigned = UInt8 | UInt16 | UInt32 | UInt64
  alias Primitive = Signed | Unsigned

  def ~
    self ^ -1
  end

  def /(x : Int)
    if x == 0
      raise DivisionByZero.new
    end

    unsafe_div x
  end

  def fdiv(other)
    to_f / other
  end

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
  # 8000 << 1  # => 4000
  # 8000 << 2  # => 2000
  # 8000 << 32 # => 0
  # 8000 << -1 # => 16000
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

  def **(other : Int)
    (to_f ** other)
  end

  def **(other)
    to_f ** other
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

  def hash
    self
  end

  def succ
    self + 1
  end

  def pred
    self - 1
  end

  def times(&block : self ->)
    i = self ^ self
    while i < self
      yield i
      i += 1
    end
    self
  end

  def times
    TimesIterator(typeof(self)).new(self)
  end

  def upto(n, &block : self ->)
    x = self
    while x <= n
      yield x
      x += 1
    end
    self
  end

  def upto(n)
    UptoIterator(typeof(self), typeof(n)).new(self, n)
  end

  def downto(n, &block : self ->)
    x = self
    while x >= n
      yield x
      x -= 1
    end
    self
  end

  def downto(n)
    DowntoIterator(typeof(self), typeof(n)).new(self, n)
  end

  def to(n, &block : self ->)
    if self < n
      upto(n) { |i| yield i }
    elsif self > n
      downto(n) { |i| yield i }
    else
      yield self
    end
    self
  end

  def to(n)
    self <= n ? upto(n) : downto(n)
  end

  def modulo(other)
    self % other
  end

  # :nodoc:
  DIGITS_DOWNCASE = "0123456789abcdefghijklmnopqrstuvwxyz"
  # :nodoc:
  DIGITS_UPCASE = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  # :nodoc:
  DIGITS_BASE62 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  def to_s
    to_s(10)
  end

  def to_s(io : IO)
    to_s(10, io)
  end

  def to_s(base : Int, upcase = false : Bool)
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

  def to_s(base : Int, io : IO, upcase = false : Bool)
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
    chars = uninitialized UInt8[65]
    ptr_end = chars.to_unsafe + 64
    ptr = ptr_end
    num = self

    neg = num < 0

    digits = (base == 62 ? DIGITS_BASE62 : (upcase ? DIGITS_UPCASE : DIGITS_DOWNCASE)).to_unsafe

    while num != 0
      ptr -= 1
      ptr.value = digits[num.remainder(base).abs]
      num /= base
    end

    if neg
      ptr -= 1
      ptr.value = '-'.ord.to_u8
    end

    count = (ptr_end - ptr).to_i32
    yield ptr, count
  end

  # Writes this integer to the given *io* in the given *format*.
  #
  # See `IO#write_bytes`.
  def to_io(io : IO, format : IO::ByteFormat)
    format.encode(self, io)
  end

  # Reads an integer from the given *io* in the given *format*.
  #
  # See `IO#read_bytes`.
  def self.from_io(io : IO, format : IO::ByteFormat)
    format.decode(self, io)
  end

  # Counts `1`-bits in the binary representation of this integer.
  #
  # ```
  # 5.popcount   # => 2
  # -15.popcount # => 5
  # ```
  abstract def popcount

  # :nodoc:
  class TimesIterator(T)
    include Iterator(T)

    def initialize(@n : T, @index = 0)
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
      @index = 0
      self
    end
  end

  # :nodoc:
  class UptoIterator(T, N)
    include Iterator(T)

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

  # :nodoc:
  class DowntoIterator(T, N)
    include Iterator(T)

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

  def -
    0_i8 - self
  end

  def popcount
    Intrinsics.popcount8(self)
  end
end

struct Int16
  MIN = -32768_i16
  MAX =  32767_i16

  def -
    0_i16 - self
  end

  def popcount
    Intrinsics.popcount16(self)
  end
end

struct Int32
  MIN = -2147483648_i32
  MAX =  2147483647_i32

  def -
    0 - self
  end

  def popcount
    Intrinsics.popcount32(self)
  end
end

struct Int64
  MIN = -9223372036854775808_i64
  MAX =  9223372036854775807_i64

  def -
    0_i64 - self
  end

  def popcount
    Intrinsics.popcount64(self)
  end
end

struct UInt8
  MIN =   0_u8
  MAX = 255_u8

  def abs
    self
  end

  def popcount
    Intrinsics.popcount8(self)
  end
end

struct UInt16
  MIN =     0_u16
  MAX = 65535_u16

  def abs
    self
  end

  def popcount
    Intrinsics.popcount16(self)
  end
end

struct UInt32
  MIN =          0_u32
  MAX = 4294967295_u32

  def abs
    self
  end

  def popcount
    Intrinsics.popcount32(self)
  end
end

struct UInt64
  MIN =                    0_u64
  MAX = 18446744073709551615_u64

  def abs
    self
  end

  def popcount
    Intrinsics.popcount64(self)
  end
end
