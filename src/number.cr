# The top-level number type.
struct Number
  include Comparable(Number)

  alias Primitive = Int::Primitive | Float::Primitive

  def self.zero : self
    new(0)
  end

  # Returns self.
  def +
    self
  end

  # Creates an `Array` of `self` with the given values, which will be casted
  # to this type with the `new` method (defined in each `Number` type).
  #
  # ```
  # floats = Float64[1, 2, 3, 4]
  # floats.class # => Array(Float64)
  #
  # ints = Int64[1, 2, 3]
  # ints.class # => Array(Int64)
  # ```
  macro [](*nums)
    Array({{@type}}).build({{nums.size}}) do |%buffer|
      {% for num, i in nums %}
        %buffer[{{i}}] = {{@type}}.new({{num}})
      {% end %}
      {{nums.size}}
    end
  end

  # Creates a `Slice` of `self` with the given values, which will be casted
  # to this type with the `new` method (defined in each `Number` type).
  #
  # The slice is allocated on the heap.
  #
  # ```
  # floats = Float64.slice(1, 2, 3, 4)
  # floats.class # => Slice(Float64)
  #
  # ints = Int64.slice(1, 2, 3)
  # ints.class # => Slice(Int64)
  # ```
  macro slice(*nums, read_only = false)
    %slice = Slice({{@type}}).new({{nums.size}}, read_only: {{read_only}})
    {% for num, i in nums %}
      %slice.to_unsafe[{{i}}] = {{@type}}.new({{num}})
    {% end %}
    %slice
  end

  # Creates a `StaticArray` of `self` with the given values, which will be casted
  # to this type with the `new` method (defined in each `Number` type).
  #
  # ```
  # floats = Float64.static_array(1, 2, 3, 4)
  # floats.class # => StaticArray(Float64, 4)
  #
  # ints = Int64.static_array(1, 2, 3)
  # ints.class # => StaticArray(Int64, 3)
  # ```
  macro static_array(*nums)
    %array = uninitialized StaticArray({{@type}}, {{nums.size}})
    {% for num, i in nums %}
      %array.to_unsafe[{{i}}] = {{@type}}.new({{num}})
    {% end %}
    %array
  end

  # Invokes the given block with the sequence of numbers starting at `self`,
  # incremented by *by* on each call, and with an optional *to*.
  #
  # ```
  # 3.step(to: 10, by: 2) do |n|
  #   puts n
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # 3
  # 5
  # 7
  # 9
  # ```
  def step(*, to = nil, by = 1)
    x = self + (by - by)

    if to
      if by > 0
        while x <= to
          yield x
          x += by
        end
      elsif by < 0
        while x >= to
          yield x
          x += by
        end
      end
    else
      while true
        yield x
        x += by
      end
    end

    self
  end

  def step(*, to = nil, by = 1)
    StepIterator.new(self + (by - by), to, by)
  end

  # Returns the absolute value of this number.
  #
  # ```
  # 123.abs  # => 123
  # -123.abs # => 123
  # ```
  def abs
    self < 0 ? -self : self
  end

  # Returns the square of `self` (`self * self`).
  #
  # ```
  # 4.abs2   # => 16
  # 1.5.abs2 # => 2.25
  # ```
  def abs2
    self * self
  end

  # Returns the sign of this number as an `Int32`.
  # * `-1` if this number is negative
  # * `0` if this number is zero
  # * `1` if this number is positive
  #
  # ```
  # 123.sign # => 1
  # 0.sign   # => 0
  # -42.sign # => -1
  # ```
  def sign
    self < 0 ? -1 : (self == 0 ? 0 : 1)
  end

  # Returns a `Tuple` of two elements containing the quotient
  # and modulus obtained by dividing `self` by *number*.
  #
  # ```
  # 11.divmod(3)  # => {3, 2}
  # 11.divmod(-3) # => {-4, -1}
  # ```
  def divmod(number)
    {(self / number).floor, self % number}
  end

  # Implements the comparison operator.
  #
  # See also: `Object#<=>`.
  def <=>(other)
    self > other ? 1 : (self < other ? -1 : 0)
  end

  # Keeps *digits* significants digits of this number in the given *base*.
  #
  # ```
  # 1234.567.significant(1) # => 1000
  # 1234.567.significant(2) # => 1200
  # 1234.567.significant(3) # => 1230
  # 1234.567.significant(4) # => 1235
  # 1234.567.significant(5) # => 1234.6
  # 1234.567.significant(6) # => 1234.57
  # 1234.567.significant(7) # => 1234.567
  # 1234.567.significant(8) # => 1234.567
  #
  # 15.159.significant(1, base = 2) # => 16
  # ```
  def significant(digits, base = 10)
    if digits < 0
      raise ArgumentError.new "digits should be non-negative"
    end

    x = self.to_f

    if x == 0
      return x
    end

    y = if base == 10
          10 ** ((Math.log10(self.abs) - digits + 1).floor)
        elsif base == 2
          2 ** ((Math.log2(self.abs) - digits + 1).floor)
        else
          base ** (((Math.log2(self.abs)) / (Math.log2(base)) - digits + 1).floor)
        end

    self.class.new((x / y).round * y)
  end

  # Rounds this number to a given precision in decimal *digits*.
  #
  # ```
  # -1763.116.round(2) # => -1763.12
  # ```
  def round(digits, base = 10)
    x = self.to_f
    if digits < 0
      y = base ** (-digits)
      self.class.new((x / y).round * y)
    else
      y = base ** digits
      self.class.new((x * y).round / y)
    end
  end

  # Clamps a value within *range*.
  #
  # ```
  # 5.clamp(10..100)   # => 10
  # 50.clamp(10..100)  # => 50
  # 500.clamp(10..100) # => 100
  # ```
  def clamp(range : Range)
    raise ArgumentError.new("Can't clamp an exclusive range") if range.exclusive?
    clamp range.begin, range.end
  end

  # Clamps a value between *min* and *max*.
  #
  # ```
  # 5.clamp(10, 100)   # => 10
  # 50.clamp(10, 100)  # => 50
  # 500.clamp(10, 100) # => 100
  # ```
  def clamp(min, max)
    return max if self > max
    return min if self < min
    self
  end

  # Returns `true` if value is equal to zero.
  #
  # ```
  # 0.zero? # => true
  # 5.zero? # => false
  # ```
  def zero? : Bool
    self == 0
  end

  private class StepIterator(T, L, B)
    include Iterator(T)

    @n : T
    @to : L
    @by : B
    @original : T

    def initialize(@n : T, @to : L, @by : B)
      @original = @n
    end

    def next
      if to = @to
        if @by > 0
          return stop if @n > to
        elsif @by < 0
          return stop if @n < to
        end

        value = @n
        @n += @by
        value
      else
        value = @n
        @n += @by
        value
      end
    end

    def rewind
      @n = @original
      self
    end
  end

  # Hash implementation.
  #
  # Based on https://github.com/python/cpython/blob/f051e43/Python/pyhash.c#L34
  module Hasher
    private HASH_NAN      =      0
    private HASH_INFINITY = 314159
    private HASH_BITS     =     31 # sizeof(Hashing::Type) >= 8 ? 61 : 31
    private HASH_MODULUS  = (1 << HASH_BITS) - 1
    private U32_MINUS_ONE = -1.unsafe_as(UInt32)
    private U32_MINUS_TWO = -2.unsafe_as(UInt32)

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
  end
end
