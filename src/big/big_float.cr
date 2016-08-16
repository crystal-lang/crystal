require "c/string"
require "./big"

# A BigFloat can represent arbitrarily large floats.
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

  def hash
    to_f64.hash
  end

  def self.default_precision
    LibGMP.mpf_get_default_prec
  end

  def self.default_precision=(prec : Int)
    LibGMP.mpf_set_default_prec(prec.to_u64)
  end

  def <=>(other : BigFloat)
    LibGMP.mpf_cmp(self, other)
  end

  def <=>(other : Float)
    LibGMP.mpf_cmp_d(self, other.to_f64)
  end

  def <=>(other : Int::Signed)
    LibGMP.mpf_cmp_si(self, other.to_i64)
  end

  def <=>(other : Int::Unsigned)
    LibGMP.mpf_cmp_ui(self, other.to_u64)
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
    BigFloat.new { |mpf| LibGMP.mpf_div(mpf, self, other.to_big_f) }
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
