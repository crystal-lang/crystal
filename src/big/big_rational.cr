require "big"

# Rational numbers are represented as the quotient of arbitrarily large
# numerators and denominators. Rationals are canonicalized such that the
# denominator and the numerator have no common factors, and that the
# denominator is positive. Zero has the unique representation 0/1.
#
# ```
# require "big"
#
# r = BigRational.new(7.to_big_i, 3.to_big_i)
# r.to_s # => "7/3"
#
# r = BigRational.new(3, -9)
# r.to_s # => "-1/3"
# ```
#
# It is implemented under the hood with [GMP](https://gmplib.org/).
struct BigRational < Number
  include Comparable(BigRational)
  include Comparable(Int)
  include Comparable(Float)

  private MANTISSA_BITS  = 53
  private MANTISSA_SHIFT = (1_i64 << MANTISSA_BITS).to_f64

  # Creates a new `BigRational`.
  #
  # If *denominator* is 0, this will raise an exception.
  def initialize(numerator : Int, denominator : Int)
    check_division_by_zero denominator

    numerator = BigInt.new(numerator) unless numerator.is_a?(BigInt)
    denominator = BigInt.new(denominator) unless denominator.is_a?(BigInt)

    LibGMP.mpq_init(out @mpq)
    LibGMP.mpq_set_num(mpq, numerator.to_unsafe)
    LibGMP.mpq_set_den(mpq, denominator.to_unsafe)
    LibGMP.mpq_canonicalize(mpq)
  end

  # Creates a new `BigRational` with *num* as the numerator and 1 for denominator.
  def initialize(num : Int)
    initialize(num, 1)
  end

  # Creates a exact representation of float as rational.
  def initialize(num : Float)
    # It ensures that `BigRational.new(f) == f`
    # It relies on fact, that mantissa is at most 53 bits
    frac, exp = Math.frexp num
    ifrac = (frac.to_f64 * MANTISSA_SHIFT).to_i64
    exp -= MANTISSA_BITS
    initialize ifrac, 1
    if exp >= 0
      LibGMP.mpq_mul_2exp(out @mpq, self, exp)
    else
      LibGMP.mpq_div_2exp(out @mpq, self, -exp)
    end
  end

  # Creates a `BigRational` from the given *num*.
  def self.new(num : BigRational)
    num
  end

  # :ditto:
  def self.new(num : BigDecimal)
    num.to_big_r
  end

  # :nodoc:
  def initialize(@mpq : LibGMP::MPQ)
  end

  # :nodoc:
  def self.new
    LibGMP.mpq_init(out mpq)
    yield pointerof(mpq)
    new(mpq)
  end

  def numerator
    BigInt.new { |mpz| LibGMP.mpq_get_num(mpz, self) }
  end

  def denominator
    BigInt.new { |mpz| LibGMP.mpq_get_den(mpz, self) }
  end

  def <=>(other : BigRational)
    LibGMP.mpq_cmp(mpq, other)
  end

  def <=>(other : Float32 | Float64)
    self <=> BigRational.new(other)
  end

  def <=>(other : Float)
    to_big_f <=> other.to_big_f
  end

  def <=>(other : Int)
    LibGMP.mpq_cmp(mpq, other.to_big_r)
  end

  def +(other : BigRational)
    BigRational.new { |mpq| LibGMP.mpq_add(mpq, self, other) }
  end

  def +(other : Int)
    self + other.to_big_r
  end

  def -(other : BigRational)
    BigRational.new { |mpq| LibGMP.mpq_sub(mpq, self, other) }
  end

  def -(other : Int)
    self - other.to_big_r
  end

  def *(other : BigRational)
    BigRational.new { |mpq| LibGMP.mpq_mul(mpq, self, other) }
  end

  def *(other : Int)
    self * other.to_big_r
  end

  def /(other : BigRational)
    check_division_by_zero other
    BigRational.new { |mpq| LibGMP.mpq_div(mpq, self, other) }
  end

  Number.expand_div [BigInt, BigFloat, BigDecimal], BigRational

  def ceil
    diff = (denominator - numerator % denominator) % denominator
    BigRational.new(numerator + diff, denominator)
  end

  def floor
    BigRational.new(numerator - numerator % denominator, denominator)
  end

  def trunc
    self < 0 ? ceil : floor
  end

  # Divides the rational by (2 ** *other*)
  #
  # ```
  # require "big"
  #
  # BigRational.new(2, 3) >> 2 # => 1/6
  # ```
  def >>(other : Int)
    BigRational.new { |mpq| LibGMP.mpq_div_2exp(mpq, self, other) }
  end

  # Multiplies the rational by (2 ** *other*)
  #
  # ```
  # require "big"
  #
  # BigRational.new(2, 3) << 2 # => 8/3
  # ```
  def <<(other : Int)
    BigRational.new { |mpq| LibGMP.mpq_mul_2exp(mpq, self, other) }
  end

  def -
    BigRational.new { |mpq| LibGMP.mpq_neg(mpq, self) }
  end

  # Raises the rational to the *other*th power
  #
  # This will raise `DivisionByZeroError` if rational is 0 and *other* is negative.
  #
  # ```
  # require "big"
  #
  # BigRational.new(2, 3) ** 2  # => 4/9
  # BigRational.new(2, 3) ** -1 # => 3/2
  # ```
  def **(other : Int) : BigRational
    if other < 0
      return (self ** -other).inv
    end
    BigRational.new(numerator ** other, denominator ** other)
  end

  # Returns a new `BigRational` as 1/r.
  #
  # This will raise an exception if rational is 0.
  def inv
    check_division_by_zero self
    BigRational.new { |mpq| LibGMP.mpq_inv(mpq, self) }
  end

  def abs
    BigRational.new { |mpq| LibGMP.mpq_abs(mpq, self) }
  end

  # TODO: improve this
  def_hash to_f64

  # Returns the `Float64` representing this rational.
  def to_f
    to_f64
  end

  def to_f32
    to_f64.to_f32
  end

  def to_f64
    LibGMP.mpq_get_d(mpq)
  end

  def to_f32!
    to_f64.to_f32!
  end

  def to_f64!
    to_f64
  end

  def to_f!
    to_f64!
  end

  delegate to_i8, to_i16, to_i32, to_i64, to_u8, to_u16, to_u32, to_u64, to: to_f64

  def to_big_f
    BigFloat.new { |mpf| LibGMP.mpf_set_q(mpf, mpq) }
  end

  def to_big_i
    BigInt.new { |mpz| LibGMP.set_q(mpz, mpq) }
  end

  # Returns the string representing this rational.
  #
  # Optionally takes a radix base (2 through 36).
  #
  # ```
  # require "big"
  #
  # r = BigRational.new(8243243, 562828882)
  # r.to_s     # => "8243243/562828882"
  # r.to_s(16) # => "7dc82b/218c1652"
  # r.to_s(36) # => "4woiz/9b3djm"
  # ```
  def to_s(base : Int = 10) : String
    String.new(to_cstr(base))
  end

  def to_s(io : IO, base : Int = 10) : Nil
    str = to_cstr(base)
    io.write_utf8 Slice.new(str, LibC.strlen(str))
  end

  def inspect : String
    to_s
  end

  def inspect(io : IO) : Nil
    to_s io
  end

  def clone
    self
  end

  private def mpq
    pointerof(@mpq)
  end

  def to_unsafe
    mpq
  end

  private def to_cstr(base = 10)
    raise "Invalid base #{base}" unless 2 <= base <= 36
    LibGMP.mpq_get_str(nil, base, mpq)
  end

  private def check_division_by_zero(value)
    raise DivisionByZeroError.new if value == 0
  end
end

struct Int
  include Comparable(BigRational)

  # Returns a `BigRational` representing this integer.
  # ```
  # require "big"
  #
  # 123.to_big_r
  # ```
  def to_big_r
    BigRational.new(self, 1)
  end

  def <=>(other : BigRational)
    -(other <=> self)
  end

  def +(other : BigRational)
    other + self
  end

  def -(other : BigRational)
    self.to_big_r - other
  end

  def /(other : BigRational)
    self.to_big_r / other
  end

  def *(other : BigRational)
    other * self
  end
end

struct Float
  include Comparable(BigRational)

  # Returns a `BigRational` representing this float.
  # ```
  # require "big"
  #
  # 123.0.to_big_r
  # ```
  def to_big_r
    BigRational.new(self)
  end

  def <=>(other : BigRational)
    -(other <=> self)
  end
end

module Math
  # Returns the sqrt of a `BigRational`.
  # ```
  # require "big"
  #
  # Math.sqrt((1000_000_000_0000.to_big_r*1000_000_000_00000.to_big_r))
  # ```
  def sqrt(value : BigRational)
    sqrt(value.to_big_f)
  end
end

# :nodoc:
struct Crystal::Hasher
  private HASH_MODULUS_RAT_P = BigRational.new((1_u64 << HASH_BITS) - 1)
  private HASH_MODULUS_RAT_N = -BigRational.new((1_u64 << HASH_BITS) - 1)

  def float(value : BigRational)
    rem = value
    if value >= HASH_MODULUS_RAT_P || value <= HASH_MODULUS_RAT_N
      num = value.numerator
      denom = value.denominator
      div = num.tdiv(denom)
      floor = div.tdiv(HASH_MODULUS)
      rem -= floor * HASH_MODULUS
    end
    rem.to_big_f.hash
  end
end
