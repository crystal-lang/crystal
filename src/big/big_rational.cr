require "./big"

# Rational numbers are represented as the quotient of arbitrarily large
# numerators and denominators. Rationals are canonicalized such that the
# denominator and the numerator have no common factors, and that the
# denominator is positive. Zero has the unique representation 0/1.
#
#     r = BigRational.new(BigInt.new(7),BigInt.new(3))
#     r.to_s # => "7/3"
#     r = BigRational.new(3,-9)
#     r.to_s # => "-1/3"
#
# It is implemented under the hood with [GMP](https://gmplib.org/).
struct BigRational < Number
  include Comparable(BigRational)
  include Comparable(Int)
  include Comparable(Float)

  # Create a new BigRational.
  #
  # If `denominator` is 0, this will raise an exception.
  def initialize(numerator : Int, denominator : Int)
    check_division_by_zero denominator

    numerator = BigInt.new(numerator) unless numerator.is_a?(BigInt)
    denominator = BigInt.new(denominator) unless denominator.is_a?(BigInt)

    LibGMP.mpq_init(out @mpq)
    LibGMP.mpq_set_num(mpq, numerator.to_unsafe)
    LibGMP.mpq_set_den(mpq, denominator.to_unsafe)
    LibGMP.mpq_canonicalize(mpq)
  end

  # Creates a new BigRational with *num* as the numerator and 1 for denominator.
  def initialize(num : Int)
    initialize(num, 1)
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

  def <=>(other : BigRational) : Order
    Order.from_value LibGMP.mpq_cmp(mpq, other)
  end

  def <=>(other : Float) : Order
    self.to_f <=> other
  end

  def <=>(other : Int) : Order
    Order.from_value LibGMP.mpq_cmp(mpq, other.to_big_r)
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

  def /(other : Int)
    self / other.to_big_r
  end

  # Divides the rational by (2**`other`)
  #
  #     BigRational.new(2,3) >> 2 # => 1/6
  def >>(other : Int)
    BigRational.new { |mpq| LibGMP.mpq_div_2exp(mpq, self, other) }
  end

  # Multiplies the rational by (2**`other`)
  #
  #     BigRational.new(2,3) << 2 # => 8/3
  def <<(other : Int)
    BigRational.new { |mpq| LibGMP.mpq_mul_2exp(mpq, self, other) }
  end

  def -
    BigRational.new { |mpq| LibGMP.mpq_neg(mpq, self) }
  end

  # Returns a new BigRational as 1/r.
  #
  # This will raise an exception if rational is 0.
  def inv
    check_division_by_zero self
    BigRational.new { |mpq| LibGMP.mpq_inv(mpq, self) }
  end

  def abs
    BigRational.new { |mpq| LibGMP.mpq_abs(mpq, self) }
  end

  def hash
    to_f64.hash
  end

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

  # Returns the string representing this rational.
  #
  # Optionally takes a radix base (2 through 36).
  #
  #     r = BigRational.new(8243243,562828882)
  #     r.to_s     # => "8243243/562828882"
  #     r.to_s(16) # => "7dc82b/218c1652"
  #     r.to_s(36) # => "4woiz/9b3djm"
  def to_s(base = 10)
    String.new(to_cstr(base))
  end

  def to_s(io : IO, base = 10)
    str = to_cstr(base)
    io.write_utf8 Slice.new(str, LibC.strlen(str))
  end

  def inspect
    to_s
  end

  def inspect(io)
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
    raise DivisionByZero.new if value == 0
  end
end

struct Int
  include Comparable(BigRational)

  # Returns a BigRational representing this integer.
  def to_big_r
    BigRational.new(self, 1)
  end

  def <=>(other : BigRational) : Order
    (other <=> self).reverse
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

  def <=>(other : BigRational) : Order
    (other <=> self).reverse
  end
end
