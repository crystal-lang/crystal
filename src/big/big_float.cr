require "c/string"
require "big"

# A `BigFloat` can represent arbitrarily large floats.
#
# It is implemented under the hood with [GMP](https://gmplib.org/).
#
# NOTE: To use `BigFloat`, you must explicitly import it with `require "big"`
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

  def initialize(num : Int)
    Int.primitive_si_ui_check(num) do |si, ui, big_i|
      {
        si:    LibGMP.mpf_init_set_si(out @mpf, {{ si }}),
        ui:    LibGMP.mpf_init_set_ui(out @mpf, {{ ui }}),
        big_i: begin
          LibGMP.mpf_init(out @mpf)
          LibGMP.mpf_set_z(self, {{ big_i }})
        end,
      }
    end
  end

  def initialize(num : Float::Primitive)
    raise ArgumentError.new "Can only construct from a finite number" unless num.finite?
    LibGMP.mpf_init_set_d(out @mpf, num)
  end

  def initialize(num : Number)
    LibGMP.mpf_init_set_d(out @mpf, num.to_f64)
  end

  def initialize(num : Float, precision : Int)
    raise ArgumentError.new "Can only construct from a finite number" unless num.finite?
    LibGMP.mpf_init2(out @mpf, precision.to_u64)
    LibGMP.mpf_set_d(self, num.to_f64)
  end

  def initialize(@mpf : LibGMP::MPF)
  end

  def self.new(&)
    LibGMP.mpf_init(out mpf)
    yield pointerof(mpf)
    new(mpf)
  end

  def self.default_precision
    LibGMP.mpf_get_default_prec
  end

  def self.default_precision=(prec : Int)
    LibGMP.mpf_set_default_prec(prec.to_u64)
  end

  # :inherit:
  def nan? : Bool
    # there are no NaNs in GMP
    false
  end

  # :inherit:
  def infinite? : Int32?
    # there are no infinities in GMP
    nil
  end

  def <=>(other : BigFloat)
    LibGMP.mpf_cmp(self, other)
  end

  def <=>(other : BigInt)
    LibGMP.mpf_cmp_z(self, other)
  end

  def <=>(other : Float::Primitive)
    LibGMP.mpf_cmp_d(self, other) unless other.nan?
  end

  def <=>(other : Int)
    Int.primitive_si_ui_check(other) do |si, ui, big_i|
      {
        si:    LibGMP.mpf_cmp_si(self, {{ si }}),
        ui:    LibGMP.mpf_cmp_ui(self, {{ ui }}),
        big_i: self <=> {{ big_i }},
      }
    end
  end

  def <=>(other : Number)
    LibGMP.mpf_cmp(self, other.to_big_f)
  end

  def - : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_neg(mpf, self) }
  end

  def +(other : Int::Primitive) : BigFloat
    Int.primitive_ui_check(other) do |ui, neg_ui, big_i|
      {
        ui:     BigFloat.new { |mpf| LibGMP.mpf_add_ui(mpf, self, {{ ui }}) },
        neg_ui: BigFloat.new { |mpf| LibGMP.mpf_sub_ui(mpf, self, {{ neg_ui }}) },
        big_i:  self + {{ big_i }},
      }
    end
  end

  def +(other : Number) : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_add(mpf, self, other.to_big_f) }
  end

  def -(other : Int::Primitive) : BigFloat
    Int.primitive_ui_check(other) do |ui, neg_ui, big_i|
      {
        ui:     BigFloat.new { |mpf| LibGMP.mpf_sub_ui(mpf, self, {{ ui }}) },
        neg_ui: BigFloat.new { |mpf| LibGMP.mpf_add_ui(mpf, self, {{ neg_ui }}) },
        big_i:  self - {{ big_i }},
      }
    end
  end

  def -(other : Number) : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_sub(mpf, self, other.to_big_f) }
  end

  def *(other : Int::Primitive) : BigFloat
    Int.primitive_ui_check(other) do |ui, neg_ui, big_i|
      {
        ui:     BigFloat.new { |mpf| LibGMP.mpf_mul_ui(mpf, self, {{ ui }}) },
        neg_ui: BigFloat.new { |mpf| LibGMP.mpf_mul_ui(mpf, self, {{ neg_ui }}); LibGMP.mpf_neg(mpf, mpf) },
        big_i:  self + {{ big_i }},
      }
    end
  end

  def *(other : Number) : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_mul(mpf, self, other.to_big_f) }
  end

  def /(other : Int::Primitive) : BigFloat
    # Division by 0 in BigFloat is not allowed, there is no BigFloat::Infinity
    raise DivisionByZeroError.new if other == 0
    Int.primitive_ui_check(other) do |ui, neg_ui, _|
      {
        ui:     BigFloat.new { |mpf| LibGMP.mpf_div_ui(mpf, self, {{ ui }}) },
        neg_ui: BigFloat.new { |mpf| LibGMP.mpf_div_ui(mpf, self, {{ neg_ui }}); LibGMP.mpf_neg(mpf, mpf) },
        big_i:  BigFloat.new { |mpf| LibGMP.mpf_div(mpf, self, BigFloat.new(other)) },
      }
    end
  end

  def /(other : BigFloat) : BigFloat
    # Division by 0 in BigFloat is not allowed, there is no BigFloat::Infinity
    raise DivisionByZeroError.new if other == 0
    BigFloat.new { |mpf| LibGMP.mpf_div(mpf, self, other) }
  end

  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational

  def **(other : BigInt) : BigFloat
    is_zero = self.zero?
    if is_zero
      case other
      when .>(0)
        return self
      when .<(0)
        # there is no BigFloat::Infinity
        raise ArgumentError.new "Cannot raise 0 to a negative power"
      end
    end

    BigFloat.new do |result|
      LibGMP.mpf_init_set_si(result, 1)
      next if is_zero # define `0 ** 0 == 1`

      # these are mutated and must be copies of `other` and `self`!
      exponent = BigInt.new { |mpz| LibGMP.abs(mpz, other) } # `other.abs`
      k = BigFloat.new { |mpf| LibGMP.mpf_set(mpf, self) }   # `self`

      while exponent > 0
        LibGMP.mpf_mul(result, result, k) if exponent.to_i!.odd? # `result *= k`
        LibGMP.fdiv_q_2exp(exponent, exponent, 1)                # `exponent /= 2`
        LibGMP.mpf_mul(k, k, k) if exponent > 0                  # `k *= k`
      end

      LibGMP.mpf_ui_div(result, 1, result) if other < 0 # `result = 1 / result`
    end
  end

  def **(other : Int) : BigFloat
    # there is no BigFloat::Infinity
    if zero? && other < 0
      raise ArgumentError.new "Cannot raise 0 to a negative power"
    end

    Int.primitive_ui_check(other) do |ui, neg_ui, big_i|
      {
        ui:     BigFloat.new { |mpf| LibGMP.mpf_pow_ui(mpf, self, {{ ui }}) },
        neg_ui: BigFloat.new { |mpf| LibGMP.mpf_pow_ui(mpf, self, {{ neg_ui }}); LibGMP.mpf_ui_div(mpf, 1, mpf) },
        big_i:  self ** {{ big_i }},
      }
    end
  end

  def abs : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_abs(mpf, self) }
  end

  # Rounds towards positive infinity.
  def ceil : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_ceil(mpf, self) }
  end

  # Rounds towards negative infinity.
  def floor : BigFloat
    BigFloat.new { |mpf| LibGMP.mpf_floor(mpf, self) }
  end

  # Rounds towards zero.
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

  def to_i64 : Int64
    raise OverflowError.new unless LibGMP::Long::MIN <= self <= LibGMP::Long::MAX
    LibGMP.mpf_get_si(self).to_i64!
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

  def to_i8! : Int8
    LibGMP.mpf_get_si(self).to_i8!
  end

  def to_i16! : Int16
    LibGMP.mpf_get_si(self).to_i16!
  end

  def to_i32! : Int32
    LibGMP.mpf_get_si(self).to_i32!
  end

  def to_i64! : Int64
    LibGMP.mpf_get_si(self).to_i64!
  end

  def to_u64 : UInt64
    raise OverflowError.new unless 0 <= self <= LibGMP::ULong::MAX
    LibGMP.mpf_get_ui(self).to_u64!
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

  def to_u8! : UInt8
    LibGMP.mpf_get_ui(self).to_u8!
  end

  def to_u16! : UInt16
    LibGMP.mpf_get_ui(self).to_u16!
  end

  def to_u32! : UInt32
    LibGMP.mpf_get_ui(self).to_u32!
  end

  def to_u64! : UInt64
    LibGMP.mpf_get_ui(self).to_u64!
  end

  def to_unsafe
    mpf
  end

  def to_s(io : IO) : Nil
    to_s_impl(io, point_range: -3..15, int_trailing_zeros: true)
  end

  protected def to_s_impl(*, point_range : Range, int_trailing_zeros : Bool) : String
    String.build { |io| to_s_impl(io, point_range: point_range, int_trailing_zeros: int_trailing_zeros) }
  end

  protected def to_s_impl(io : IO, *, point_range : Range, int_trailing_zeros : Bool) : Nil
    cstr = LibGMP.mpf_get_str(nil, out orig_decimal_exponent, 10, 0, self)
    buffer = Slice.new(cstr, LibC.strlen(cstr))

    # add negative sign
    if buffer[0]? == 45 # '-'
      io << '-'
      buffer = buffer[1..]
    end

    decimal_exponent = fix_exponent_overflow(orig_decimal_exponent) - buffer.size
    if int_trailing_zeros
      # GMP ensures `cstr` contains no trailing zeros
      fraction = Float::Printer::FractionMode::WriteAll
    else
      # used by the Ryu Printf specs only
      fraction = Float::Printer::FractionMode::RemoveIfZero
    end

    Float::Printer.decimal(io, buffer, decimal_exponent, point_range, fraction)
  end

  # The same `LibGMP::MpExp` is used in `LibGMP::MPF` to represent a
  # `BigFloat`'s exponent in base `256 ** sizeof(LibGMP::MpLimb)`, and to return
  # a base-10 exponent in `LibGMP.mpf_get_str`. The latter is around 9.6x the
  # former when `MpLimb` is 32-bit, or around 19.3x when `MpLimb` is 64-bit.
  # This means the base-10 exponent will overflow for the majority of `MpExp`'s
  # domain, even though `BigFloat`s will work correctly in this exponent range
  # otherwise. This method exists to recover the original exponent for `#to_s`.
  #
  # Note that if `MpExp` is 64-bit, which is the case for non-Windows 64-bit
  # targets, then `mpf_get_str` will simply crash for values above
  # `2 ** 0x1_0000_0000_0000_0080`; here `exponent10` is around 5.553e+18, and
  # never overflows. Thus there is no need to check for overflow in that case.
  private def fix_exponent_overflow(exponent10)
    {% if LibGMP::MpExp == Int64 %}
      exponent10
    {% else %}
      # When `self` is non-zero,
      #
      #     @mpf.@_mp_exp == Math.log(abs, 256.0 ** sizeof(LibGMP::MpLimb)).floor + 1
      #     @mpf.@_mp_exp - 1 <= Math.log(abs, 256.0 ** sizeof(LibGMP::MpLimb)) < @mpf.@_mp_exp
      #     @mpf.@_mp_exp - 1 <= Math.log10(abs) / Math.log10(256.0 ** sizeof(LibGMP::MpLimb)) < @mpf.@_mp_exp
      #     Math.log10(abs) >= (@mpf.@_mp_exp - 1) * Math.log10(256.0 ** sizeof(LibGMP::MpLimb))
      #     Math.log10(abs) <   @mpf.@_mp_exp      * Math.log10(256.0 ** sizeof(LibGMP::MpLimb))
      #
      # And also,
      #
      #     exponent10 == Math.log10(abs).floor + 1
      #     exponent10 - 1 <= Math.log10(abs) < exponent10
      #
      # When `exponent10` overflows, it differs from its real value by an
      # integer multiple of `256.0 ** sizeof(LibGMP::MpExp)`. We have to recover
      # the integer `overflow_n` such that:
      #
      #     LibGMP::MpExp::MIN <= exponent10 <= LibGMP::MpExp::MAX
      #     Math.log10(abs) ~= exponent10 + overflow_n * 256.0 ** sizeof(LibGMP::MpExp)
      #                     ~= @mpf.@_mp_exp * Math.log10(256.0 ** sizeof(LibGMP::MpLimb))
      #
      # Because the possible intervals for the real `exponent10` are so far apart,
      # it suffices to approximate `overflow_n` as follows:
      #
      #     overflow_n ~= (@mpf.@_mp_exp * Math.log10(256.0 ** sizeof(LibGMP::MpLimb)) - exponent10) / 256.0 ** sizeof(LibGMP::MpExp)
      #
      # This value will be very close to an integer, which we then obtain with
      # `#round`.
      overflow_n = ((@mpf.@_mp_exp * Math.log10(256.0 ** sizeof(LibGMP::MpLimb)) - exponent10) / 256.0 ** sizeof(LibGMP::MpExp))
      exponent10.to_i64 + overflow_n.round.to_i64 * (256_i64 ** sizeof(LibGMP::MpExp))
    {% end %}
  end

  # :inherit:
  def format(io : IO, separator = '.', delimiter = ',', decimal_places : Int? = nil, *, group : Int = 3, only_significant : Bool = false) : Nil
    number = self
    if decimal_places
      number = number.round(decimal_places)
    end

    if decimal_places && decimal_places >= 0
      string = number.abs.to_s_impl(point_range: .., int_trailing_zeros: true)
      integer, _, decimals = string.partition('.')
    else
      string = number.to_s_impl(point_range: .., int_trailing_zeros: true)
      _, _, decimals = string.partition(".")
      integer = number.trunc.to_big_i.abs.to_s
    end

    is_negative = number < 0

    format_impl(io, is_negative, integer, decimals, separator, delimiter, decimal_places, group, only_significant)
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

  # :inherit:
  def integer? : Bool
    !LibGMP.mpf_integer_p(mpf).zero?
  end

  private def mpf
    pointerof(@mpf)
  end
end

struct Number
  include Comparable(BigFloat)

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

struct Int
  def <=>(other : BigFloat)
    -(other <=> self)
  end

  def -(other : BigFloat) : BigFloat
    Int.primitive_ui_check(self) do |ui, neg_ui, _|
      {
        ui:     BigFloat.new { |mpf| LibGMP.mpf_neg(mpf, other); LibGMP.mpf_add_ui(mpf, mpf, {{ ui }}) },
        neg_ui: BigFloat.new { |mpf| LibGMP.mpf_neg(mpf, other); LibGMP.mpf_sub_ui(mpf, mpf, {{ neg_ui }}) },
        big_i:  BigFloat.new { |mpf| LibGMP.mpf_sub(mpf, BigFloat.new(self), other) },
      }
    end
  end

  def /(other : BigFloat) : BigFloat
    # Division by 0 in BigFloat is not allowed, there is no BigFloat::Infinity
    raise DivisionByZeroError.new if other == 0

    Int.primitive_ui_check(self) do |ui, neg_ui, _|
      {
        ui:     BigFloat.new { |mpf| LibGMP.mpf_ui_div(mpf, {{ ui }}, other) },
        neg_ui: BigFloat.new { |mpf| LibGMP.mpf_ui_div(mpf, {{ neg_ui }}, other); LibGMP.mpf_neg(mpf, mpf) },
        big_i:  BigFloat.new { |mpf| LibGMP.mpf_div(mpf, BigFloat.new(self), other) },
      }
    end
  end
end

struct Float
  def <=>(other : BigFloat)
    cmp = other <=> self
    -cmp if cmp
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
  #
  # Raises `ArgumentError` if *value* is zero.
  def ilogb(value : BigFloat) : Int64
    raise ArgumentError.new "Cannot get exponent of zero" if value.zero?
    leading_zeros = value.@mpf._mp_d[value.@mpf._mp_size.abs - 1].leading_zeros_count
    8_i64 * sizeof(LibGMP::MpLimb) * value.@mpf._mp_exp - leading_zeros - 1
  end

  # Returns the unbiased radix-independent exponent of the given floating-point *value*.
  #
  # For `BigFloat` this is equivalent to `ilogb`.
  #
  # Raises `ArgumentError` is *value* is zero.
  def logb(value : BigFloat) : BigFloat
    ilogb(value).to_big_f
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
  def frexp(value : BigFloat) : {BigFloat, Int64}
    return {BigFloat.zero, 0_i64} if value.zero?

    # We compute this ourselves since `LibGMP.mpf_get_d_2exp` only returns a
    # `LibC::Long` exponent, which is not sufficient for 32-bit `LibC::Long` and
    # 32-bit `LibGMP::MpExp`, e.g. on 64-bit Windows.
    # Since `0.5 <= frac.abs < 1.0`, the radix point should be just above the
    # most significant limb, and there should be no leading zeros in that limb.
    leading_zeros = value.@mpf._mp_d[value.@mpf._mp_size.abs - 1].leading_zeros_count
    exp = 8_i64 * sizeof(LibGMP::MpLimb) * value.@mpf._mp_exp - leading_zeros

    frac = BigFloat.new do |mpf|
      # remove leading zeros in the most significant limb
      LibGMP.mpf_mul_2exp(mpf, value, leading_zeros)
      # reset the exponent manually
      mpf.value._mp_exp = 0
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
struct String::Formatter(A)
  def int(flags, arg : BigFloat) : Nil
    int(flags, arg.to_big_i)
  end
end
