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
    LibGMP.mpf_init_set_str(out @mpf, str, 10)
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

  def -
    BigFloat.new { |mpf| LibGMP.mpf_neg(mpf, self) }
  end

  def +(other : Number)
    BigFloat.new { |mpf| LibGMP.mpf_add(mpf, self, other.to_big_f) }
  end

  def -(other : Number)
    BigFloat.new { |mpf| LibGMP.mpf_sub(mpf, self, other.to_big_f) }
  end

  def *(other : Number)
    BigFloat.new { |mpf| LibGMP.mpf_mul(mpf, self, other.to_big_f) }
  end

  def /(other : Number)
    raise DivisionByZero.new if other == 0
    if other.is_a?(UInt8 | UInt16 | UInt32) || (LibGMP::ULong == UInt64 && other.is_a?(UInt64))
      BigFloat.new { |mpf| LibGMP.mpf_div_ui(mpf, self, other) }
    else
      BigFloat.new { |mpf| LibGMP.mpf_div(mpf, self, other.to_big_f) }
    end
  end

  def **(other : Int)
    BigFloat.new { |mpf| LibGMP.mpf_pow_ui(mpf, self, other.to_u64) }
  end

  def abs
    BigFloat.new { |mpf| LibGMP.mpf_abs(mpf, self) }
  end

  def ceil
    BigFloat.new { |mpf| LibGMP.mpf_ceil(mpf, self) }
  end

  def floor
    BigFloat.new { |mpf| LibGMP.mpf_floor(mpf, self) }
  end

  def trunc
    BigFloat.new { |mpf| LibGMP.mpf_trunc(mpf, self) }
  end

  def to_f64
    LibGMP.mpf_get_d(self)
  end

  def to_f32
    to_f64.to_f32
  end

  def to_f
    to_f64
  end

  def to_big_f
    self
  end

  def to_i64
    LibGMP.mpf_get_si(self)
  end

  def to_i32
    to_i64.to_i32
  end

  def to_i16
    to_i64.to_i16
  end

  def to_i8
    to_i64.to_i8
  end

  def to_i
    to_i32
  end

  def to_u64
    LibGMP.mpf_get_ui(self)
  end

  def to_u32
    to_u64.to_u32
  end

  def to_u16
    to_u64.to_u16
  end

  def to_u8
    to_u64.to_u8
  end

  def to_u
    to_u32
  end

  def to_unsafe
    mpf
  end

  def inspect(io)
    to_s(io)
    io << "_big_f"
  end

  def to_s(io : IO)
    cstr = LibGMP.mpf_get_str(nil, out expptr, 10, 0, self)
    length = LibC.strlen(cstr)
    io << '-' if self < 0
    if expptr == 0
      io << 0
    elsif expptr < 0
      io << 0 << '.'
      expptr.abs.times { io << 0 }
    end
    expptr += 1 if self < 0
    length.times do |i|
      next if cstr[i] == 45 # '-'
      io << '.' if i == expptr
      io << cstr[i].unsafe_chr
    end
    (expptr - length).times { io << 0 } if expptr > 0
  end

  def clone
    self
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

  def *(other : BigFloat)
    other * self
  end

  def to_big_f
    BigFloat.new(self)
  end
end

class String
  def to_big_f
    BigFloat.new(self)
  end
end

module Math
  def frexp(value : BigFloat)
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
end
