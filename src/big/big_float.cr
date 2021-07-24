require "c/string"
require "big"

# A `BigFloat` can represent arbitrarily large floats.
#
# It is implemented under the hood with [GMP](https://gmplib.org/).
struct BigFloat < Float
  include Comparable(Int)
  include Comparable(BigFloat)
  include Comparable(Float)

  def initialize
    LibGMP.mpf_init(out @mpf)
  end

  def initialize(str : String)
    # Strip leading '+' char to smooth out cases with strings like "+123"
    str = str.lchop('+')
    # Strip '_' to make it compatible with int literals like "1_000_000"
    str = str.delete('_')
    if LibGMP.mpf_init_set_str(out @mpf, str, 10) == -1
      raise ArgumentError.new("Invalid BigFloat: #{str.inspect}")
    end
  end

  def initialize(num : BigInt)
    LibGMP.mpf_init(out @mpf)
    LibGMP.mpf_set_z(self, num)
  end

  def initialize(num : BigRational)
    LibGMP.mpf_init(out @mpf)
    LibGMP.mpf_set_q(self, num)
  end

  def initialize(num : BigFloat)
    LibGMP.mpf_init(out @mpf)
    LibGMP.mpf_set(self, num)
  end

  def initialize(num : Int8 | Int16 | Int32)
    LibGMP.mpf_init_set_si(out @mpf, num)
  end

  def initialize(num : UInt8 | UInt16 | UInt32)
    LibGMP.mpf_init_set_ui(out @mpf, num)
  end

  def initialize(num : Int64)
    if LibGMP::Long == Int64
      LibGMP.mpf_init_set_si(out @mpf, num)
    else
      LibGMP.mpf_init(out @mpf)
      LibGMP.mpf_set_z(self, num.to_big_i)
    end
  end

  def initialize(num : UInt64)
    if LibGMP::ULong == UInt64
      LibGMP.mpf_init_set_ui(out @mpf, num)
    else
      LibGMP.mpf_init(out @mpf)
      LibGMP.mpf_set_z(self, num.to_big_i)
    end
  end

  def initialize(num : Number)
    LibGMP.mpf_init_set_d(out @mpf, num.to_f64)
  end

  def initialize(num : Float, precision : Int)
    LibGMP.mpf_init2(out @mpf, precision.to_u64)
    LibGMP.mpf_set_d(self, num.to_f64)
  end

  def initialize(@mpf : LibGMP::MPF)
  end

  def self.new
    LibGMP.mpf_init(out mpf)
    yield pointerof(mpf)
    new(mpf)
  end

  # TODO: improve this
  def_hash to_f64

  def self.default_precision
    LibGMP.mpf_get_default_prec
  end

  def self.default_precision=(prec : Int)
    LibGMP.mpf_set_default_prec(prec.to_u64)
  end

  def <=>(other : BigFloat)
    LibGMP.mpf_cmp(self, other)
  end

  def <=>(other : BigInt)
    LibGMP.mpf_cmp_z(self, other)
  end

  def <=>(other : Float32 | Float64)
    LibGMP.mpf_cmp_d(self, other.to_f64)
  end

  def <=>(other : Number)
    if other.is_a?(Int8 | Int16 | Int32) || (LibGMP::Long == Int64 && other.is_a?(Int64))
      LibGMP.mpf_cmp_si(self, other)
    elsif other.is_a?(UInt8 | UInt16 | UInt32) || (LibGMP::ULong == UInt64 && other.is_a?(UInt64))
      LibGMP.mpf_cmp_ui(self, other)
    else
      LibGMP.mpf_cmp(self, other.to_big_f)
    end
  end

  def - : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_neg(mpf, self) }
  end

  def +(other : Number) : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_add(mpf, self, other.to_big_f) }
  end

  def -(other : Number) : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_sub(mpf, self, other.to_big_f) }
  end

  def *(other : Number) : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_mul(mpf, self, other.to_big_f) }
  end

  def /(other : BigFloat) : BigFloat
    # Division by 0 in BigFloat is not allowed, there is no BigFloat::Infinity
    raise DivisionByZeroError.new if other == 0
    BigFloat.new { |mpf| LibGMP.mpf_div(mpf, self, other) }
  end

  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational

  def **(other : Int) : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_pow_ui(mpf, self, other.to_u64) }
  end

  def abs : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_abs(mpf, self) }
  end

  def ceil : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_ceil(mpf, self) }
  end

  def floor : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_floor(mpf, self) }
  end

  def trunc : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_trunc(mpf, self) }
  end

  def to_f64 : Float64
    LibGMP.mpf_get_d(self)
  end

  def to_f32 : Float32
    to_f64.to_f32
  end

  def to_f : Float64
    to_f64
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

  def to_big_f : BigFloat
    self
  end

  def to_big_i : BigInt
    BigInt.new { |mpz| LibGMP.set_f(mpz, mpf) }
  end

  def to_i64
    raise OverflowError.new unless LibGMP::Long::MIN <= self <= LibGMP::Long::MAX
    LibGMP.mpf_get_si(self)
  end

  def to_i32 : Int32
    to_i64.to_i32
  end

  def to_i16 : Int16
    to_i64.to_i16
  end

  def to_i8 : Int8
    to_i64.to_i8
  end

  def to_i : Int32
    to_i32
  end

  def to_i! : Int32
    to_i32!
  end

  def to_i8!
    LibGMP.mpf_get_si(self).to_i8!
  end

  def to_i16!
    LibGMP.mpf_get_si(self).to_i16!
  end

  def to_i32! : Int32
    LibGMP.mpf_get_si(self).to_i32!
  end

  def to_i64!
    LibGMP.mpf_get_si(self)
  end

  def to_u64
    raise OverflowError.new unless 0 <= self <= LibGMP::ULong::MAX
    LibGMP.mpf_get_ui(self)
  end

  def to_u32 : UInt32
    to_u64.to_u32
  end

  def to_u16 : UInt16
    to_u64.to_u16
  end

  def to_u8 : UInt8
    to_u64.to_u8
  end

  def to_u : UInt32
    to_u32
  end

  def to_u! : UInt32
    to_u32!
  end

  def to_u8!
    LibGMP.mpf_get_ui(self).to_u8!
  end

  def to_u16!
    LibGMP.mpf_get_ui(self).to_u16!
  end

  def to_u32! : UInt32
    LibGMP.mpf_get_ui(self).to_u32!
  end

  def to_u64!
    LibGMP.mpf_get_ui(self)
  end

  def to_unsafe
    mpf
  end

  def to_s(io : IO) : Nil
    cstr = LibGMP.mpf_get_str(nil, out expptr, 10, 0, self)
    length = LibC.strlen(cstr)
    decimal_set = false
    io << '-' if self < 0
    if expptr == 0
      io << 0
    elsif expptr < 0
      io << 0 << '.'
      decimal_set = true
      expptr.abs.times { io << 0 }
    end
    expptr += 1 if self < 0
    length.times do |i|
      next if cstr[i] == 45 # '-'
      if i == expptr
        io << '.'
        decimal_set = true
      end
      io << cstr[i].unsafe_chr
    end
    (expptr - length).times { io << 0 } if expptr > 0
    if !decimal_set
      io << ".0"
    end
  end

  def clone
    self
  end

  # Rounds towards the nearest integer. If both neighboring integers are equidistant,
  # rounds towards the even neighbor (Banker's rounding).
  def round_even : self
    if self >= 0
      halfway = self + 0.5
    else
      halfway = self - 0.5
    end
    if halfway.integer?
      if halfway == (halfway / 2).trunc * 2
        halfway
      else
        halfway - sign
      end
    else
      if self >= 0
        halfway.floor
      else
        halfway.ceil
      end
    end
  end

  # Rounds towards the nearest integer. If both neighboring integers are equidistant,
  # rounds away from zero.
  def round_away : self
    if self >= 0
      (self + 0.5).floor
    else
      (self - 0.5).ceil
    end
  end

  protected def integer?
    !LibGMP.mpf_integer_p(mpf).zero?
  end

  private def mpf
    pointerof(@mpf)
  end
end

struct Number
  include Comparable(BigFloat)

  def <=>(other : BigFloat)
    -(other <=> self)
  end

  def +(other : BigFloat)
    other + self
  end

  def -(other : BigFloat)
    to_big_f - other
  end

  def *(other : BigFloat) : BigFloat
    other * self
  end

  def /(other : BigFloat) : BigFloat
    to_big_f / other
  end

  def to_big_f : BigFloat
    BigFloat.new(self)
  end
end

class String
  # Converts `self` to a `BigFloat`.
  #
  # ```
  # require "big"
  # "1234.0".to_big_f
  # ```
  def to_big_f : BigFloat
    BigFloat.new(self)
  end
end

module Math
  # Returns the unbiased base 2 exponent of the given floating-point *value*.
  def ilogb(value : BigFloat) : Int64
    LibGMP.mpf_get_d_2exp(out exp, value)
    (exp - 1).to_i64
  end

  # Returns the unbiased radix-independent exponent of the given floating-point *value*.
  #
  # For `BigFloat` this is equivalent to `ilogb`.
  def logb(value : BigFloat) : BigFloat
    LibGMP.mpf_get_d_2exp(out exp, value)
    (exp - 1).to_big_f
  end

  # Multiplies the given floating-point *value* by 2 raised to the power *exp*.
  def ldexp(value : BigFloat, exp : Int) : BigFloat
    BigFloat.new do |mpf|
      if exp >= 0
        LibGMP.mpf_mul_2exp(mpf, value, exp.to_u64)
      else
        LibGMP.mpf_div_2exp(mpf, value, exp.abs.to_u64)
      end
    end
  end

  # Returns the floating-point *value* with its exponent raised by *exp*.
  #
  # For `BigFloat` this is equivalent to `ldexp`.
  def scalbn(value : BigFloat, exp : Int) : BigFloat
    ldexp(value, exp)
  end

  # :ditto:
  def scalbln(value : BigFloat, exp : Int) : BigFloat
    ldexp(value, exp)
  end

  # Decomposes the given floating-point *value* into a normalized fraction and an integral power of two.
  def frexp(value : BigFloat) : {BigFloat, Int32 | Int64}
    LibGMP.mpf_get_d_2exp(out exp, value) # we need BigFloat frac, so will skip Float64 one.
    frac = BigFloat.new do |mpf|
      if exp >= 0
        LibGMP.mpf_div_2exp(mpf, value, exp)
      else
        LibGMP.mpf_mul_2exp(mpf, value, -exp)
      end
    end
    {frac, exp}
  end

  # Returns the floating-point value with the magnitude of *value1* and the sign of *value2*.
  #
  # `BigFloat` does not support signed zeros; if `value2 == 0`, the returned value is non-negative.
  def copysign(value1 : BigFloat, value2 : BigFloat) : BigFloat
    if value1.negative? != value2.negative? # opposite signs
      -value1
    else
      value1
    end
  end

  # Calculates the square root of *value*.
  #
  # ```
  # require "big"
  #
  # Math.sqrt(1_000_000_000_000.to_big_f * 1_000_000_000_000.to_big_f) # => 1000000000000.0
  # ```
  def sqrt(value : BigFloat) : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_sqrt(mpf, value) }
  end
end

# :nodoc:
struct Crystal::Hasher
  def float(value : BigFloat)
    normalized_hash = float_normalize_wrap(value) do |value|
      # more exact version of `Math.frexp`
      LibGMP.mpf_get_d_2exp(out exp, value)
      frac = BigFloat.new do |mpf|
        if exp >= 0
          LibGMP.mpf_div_2exp(mpf, value, exp)
        else
          LibGMP.mpf_mul_2exp(mpf, value, -exp)
        end
      end
      float_normalize_reference(value, frac, exp)
    end
    permute(normalized_hash)
  end
end
