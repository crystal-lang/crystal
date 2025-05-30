require "big"

# Rational numbers are represented as the quotient of arbitrarily large
# numerators and denominators. Rationals are canonicalized such that the
# denominator and the numerator have no common factors, and that the
# denominator is positive. Zero has the unique representation 0/1.
#
# NOTE: To use `BigRational`, you must explicitly import it with `require "big"`
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

  # Creates an exact representation of float as rational.
  #
  # Raises `ArgumentError` if *num* is not finite.
  def self.new(num : Float::Primitive)
    raise ArgumentError.new "Can only construct from a finite number" unless num.finite?
    new { |mpq| LibGMP.mpq_set_d(mpq, num) }
  end

  # Creates an exact representation of float as rational.
  def self.new(num : BigFloat)
    new { |mpq| LibGMP.mpq_set_f(mpq, num) }
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
  def self.new(&)
    LibGMP.mpq_init(out mpq)
    yield pointerof(mpq)
    new(mpq)
  end

  def numerator : BigInt
    # Returns `LibGMP.mpq_numref(self)`, whose C macro expansion effectively
    # produces a raw member access. This is only as safe as copying `BigInt`s by
    # value, as both involve copying `LibGMP::MPZ` around which has reference
    # semantics, and `BigInt`s cannot be safely mutated in-place this way; see
    # #9825 for details. Ditto for `#denominator`.
    BigInt.new(@mpq._mp_num)
  end

  def denominator : BigInt
    BigInt.new(@mpq._mp_den)
  end

  def <=>(other : BigRational)
    LibGMP.mpq_cmp(mpq, other)
  end

  def <=>(other : Float::Primitive)
    self <=> BigRational.new(other) unless other.nan?
  end

  def <=>(other : BigFloat)
    self <=> other.to_big_r
  end

  def <=>(other : Int)
    Int.primitive_si_ui_check(other) do |si, ui, big_i|
      {
        si:    LibGMP.mpq_cmp_si(self, {{ si }}, 1),
        ui:    LibGMP.mpq_cmp_ui(self, {{ ui }}, 1),
        big_i: self <=> {{ big_i }},
      }
    end
  end

  def <=>(other : BigInt)
    LibGMP.mpq_cmp_z(self, other)
  end

  def ==(other : BigRational) : Bool
    LibGMP.mpq_equal(self, other) != 0
  end

  def +(other : BigRational) : BigRational
    BigRational.new { |mpq| LibGMP.mpq_add(mpq, self, other) }
  end

  def +(other : Int) : BigRational
    self + other.to_big_r
  end

  def -(other : BigRational) : BigRational
    BigRational.new { |mpq| LibGMP.mpq_sub(mpq, self, other) }
  end

  def -(other : Int) : BigRational
    self - other.to_big_r
  end

  def *(other : BigRational) : BigRational
    BigRational.new { |mpq| LibGMP.mpq_mul(mpq, self, other) }
  end

  def *(other : Int) : BigRational
    self * other.to_big_r
  end

  def /(other : BigRational) : BigRational
    check_division_by_zero other
    BigRational.new { |mpq| LibGMP.mpq_div(mpq, self, other) }
  end

  Number.expand_div [BigInt, BigFloat, BigDecimal], BigRational

  def //(other : BigRational) : BigRational
    check_division_by_zero other
    BigRational.new((numerator * other.denominator) // (denominator * other.numerator))
  end

  def //(other : Int) : BigRational
    check_division_by_zero other
    BigRational.new(numerator // (denominator * other))
  end

  def %(other : BigRational) : BigRational
    check_division_by_zero other
    BigRational.new(
      (numerator * other.denominator) % (denominator * other.numerator),
      denominator * other.denominator,
    )
  end

  def %(other : Int) : BigRational
    check_division_by_zero other
    BigRational.new(numerator % (denominator * other), denominator)
  end

  def tdiv(other : BigRational) : BigRational
    check_division_by_zero other
    BigRational.new((numerator * other.denominator).tdiv(denominator * other.numerator))
  end

  def tdiv(other : Int) : BigRational
    check_division_by_zero other
    BigRational.new(numerator.tdiv(denominator * other))
  end

  def remainder(other : BigRational) : BigRational
    check_division_by_zero other
    BigRational.new(
      (numerator * other.denominator).remainder(denominator * other.numerator),
      denominator * other.denominator,
    )
  end

  def remainder(other : Int) : BigRational
    check_division_by_zero other
    BigRational.new(numerator.remainder(denominator * other), denominator)
  end

  def ceil : BigRational
    BigRational.new(-(-numerator // denominator))
  end

  def floor : BigRational
    BigRational.new(numerator // denominator)
  end

  def trunc : BigRational
    BigRational.new(numerator.tdiv(denominator))
  end

  def round_away : BigRational
    rem2 = numerator.remainder(denominator).abs * 2
    x = BigRational.new(numerator.tdiv(denominator))
    x += sign if rem2 >= denominator
    x
  end

  def round_even : BigRational
    rem2 = numerator.remainder(denominator).abs * 2
    x = BigRational.new(numerator.tdiv(denominator))
    x += sign if rem2 > denominator || (rem2 == denominator && x.numerator.odd?)
    x
  end

  # :inherit:
  def integer? : Bool
    # since all `BigRational`s are canonicalized, the denominator must be
    # positive and coprime with the numerator
    denominator == 1
  end

  # Divides the rational by (2 ** *other*)
  #
  # ```
  # require "big"
  #
  # BigRational.new(2, 3) >> 2 # => 1/6
  # ```
  def >>(other : Int) : BigRational
    BigRational.new { |mpq| LibGMP.mpq_div_2exp(mpq, self, other) }
  end

  # Multiplies the rational by (2 ** *other*)
  #
  # ```
  # require "big"
  #
  # BigRational.new(2, 3) << 2 # => 8/3
  # ```
  def <<(other : Int) : BigRational
    BigRational.new { |mpq| LibGMP.mpq_mul_2exp(mpq, self, other) }
  end

  def - : BigRational
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
      return (self ** other.abs).inv
    end
    BigRational.new(numerator ** other, denominator ** other)
  end

  # Returns a new `BigRational` as 1/r.
  #
  # This will raise an exception if rational is 0.
  def inv : BigRational
    check_division_by_zero self
    BigRational.new { |mpq| LibGMP.mpq_inv(mpq, self) }
  end

  def abs : BigRational
    BigRational.new { |mpq| LibGMP.mpq_abs(mpq, self) }
  end

  # Returns the `Float64` representing this rational.
  def to_f : Float64
    to_f64
  end

  def to_f32 : Float32
    to_f64.to_f32
  end

  def to_f64 : Float64
    LibGMP.mpq_get_d(mpq)
  end

  def to_f32! : Float32
    to_f64.to_f32!
  end

  def to_f64! : Float64
    to_f64
  end

  def to_f! : Float64
    to_f64!
  end

  def to_i : Int32
    to_i32
  end

  delegate to_i8, to_i16, to_i32, to_i64, to_u8, to_u16, to_u32, to_u64, to: to_f64

  # Returns `self`.
  #
  # ```
  # require "big"
  #
  # BigRational.new(4, 5).to_big_r # => 4/5
  # ```
  def to_big_r : BigRational
    self
  end

  def to_big_f : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_set_q(mpf, mpq) }
  end

  def to_big_i : BigInt
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
    io.write_string Slice.new(str, LibC.strlen(str))
  end

  def inspect : String
    to_s
  end

  def inspect(io : IO) : Nil
    to_s io
  end

  # :inherit:
  def format(io : IO, separator = '.', delimiter = ',', decimal_places : Int? = nil, *, group : Int = 3, only_significant : Bool = false) : Nil
    numerator.format(io, separator, delimiter, decimal_places, group: group, only_significant: only_significant)
    io << '/'
    denominator.format(io, separator, delimiter, decimal_places, group: group, only_significant: only_significant)
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
  def to_big_r : BigRational
    BigRational.new(self, 1)
  end

  def <=>(other : BigRational)
    -(other <=> self)
  end

  def +(other : BigRational) : BigRational
    other + self
  end

  def -(other : BigRational) : BigRational
    self.to_big_r - other
  end

  def /(other : BigRational)
    self.to_big_r / other
  end

  def *(other : BigRational) : BigRational
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
  def to_big_r : BigRational
    BigRational.new(self)
  end

  def <=>(other : BigRational)
    cmp = other <=> self
    -cmp if cmp
  end
end

struct BigFloat
  def <=>(other : BigRational)
    -(other <=> self)
  end
end

module Math
  # Calculates the square root of *value*.
  #
  # ```
  # require "big"
  #
  # Math.sqrt(1_000_000_000_000.to_big_r * 1_000_000_000_000.to_big_r) # => 1000000000000.0
  # ```
  def sqrt(value : BigRational) : BigFloat
    sqrt(value.to_big_f)
  end
end

# :nodoc:
struct Crystal::Hasher
  def self.reduce_num(value : BigRational)
    inverse = BigInt.new do |mpz|
      if LibGMP.invert(mpz, value.denominator, HASH_MODULUS_INT_P) == 0
        # inverse doesn't exist, i.e. denominator is a multiple of HASH_MODULUS
        return value >= 0 ? HASH_INF_PLUS : HASH_INF_MINUS
      end
    end
    UInt64.mulmod(reduce_num(value.numerator.abs), inverse.to_u64!, HASH_MODULUS) &* value.sign
  end
end
