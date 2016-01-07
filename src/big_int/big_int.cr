require "./lib_gmp"

struct BigInt < Int
  include Comparable(Int::Signed)
  include Comparable(Int::Unsigned)
  include Comparable(BigInt)
  include Comparable(Float)

  def initialize
    LibGMP.init(out @mpz)
  end

  def initialize(str : String, base = 10)
    LibGMP.init_set_str(out @mpz, str, base)
  end

  def initialize(num : Int::Signed)
    if LibC::Long::MIN <= num <= LibC::Long::MAX
      LibGMP.init_set_si(out @mpz, num)
    else
      LibGMP.init_set_str(out @mpz, num.to_s, 10)
    end
  end

  def initialize(num : Int::Unsigned)
    if num <= LibC::ULong::MAX
      LibGMP.init_set_ui(out @mpz, num)
    else
      LibGMP.init_set_str(out @mpz, num.to_s, 10)
    end
  end

  def initialize(num : Float)
    LibGMP.init_set_d(out @mpz, num)
  end

  def initialize(@mpz : LibGMP::MPZ)
  end

  def self.new
    LibGMP.init(out mpz)
    yield pointerof(mpz)
    new(mpz)
  end

  def <=>(other : BigInt)
    LibGMP.cmp(mpz, other)
  end

  def <=>(other : Int::Signed)
    if LibC::Long::MIN <= other <= LibC::Long::MAX
      LibGMP.cmp_si(mpz, other)
    else
      self <=> BigInt.new(other)
    end
  end

  def <=>(other : Int::Unsigned)
    if other <= LibC::ULong::MAX
      LibGMP.cmp_ui(mpz, other)
    else
      self <=> BigInt.new(other)
    end
  end

  def <=>(other : Float)
    LibGMP.cmp_d(mpz, other)
  end

  def +(other : BigInt)
    BigInt.new { |mpz| LibGMP.add(mpz, self, other) }
  end

  def +(other : Int)
    if other < 0
      self - other.abs
    else
      BigInt.new { |mpz| LibGMP.add_ui(mpz, self, other) }
    end
  end

  def -(other : BigInt)
    BigInt.new { |mpz| LibGMP.sub(mpz, self, other) }
  end

  def -(other : Int)
    if other < 0
      self + other.abs
    else
      BigInt.new { |mpz| LibGMP.sub_ui(mpz, self, other) }
    end
  end

  def -
    BigInt.new { |mpz| LibGMP.neg(mpz, self) }
  end

  def abs
    BigInt.new { |mpz| LibGMP.abs(mpz, self) }
  end

  def *(other : BigInt)
    BigInt.new { |mpz| LibGMP.mul(mpz, self, other) }
  end

  def *(other : Int::Signed)
    BigInt.new { |mpz| LibGMP.mul_si(mpz, self, other) }
  end

  def *(other : Int::Unsigned)
    BigInt.new { |mpz| LibGMP.mul_ui(mpz, self, other) }
  end

  def /(other : BigInt)
    check_division_by_zero other

    BigInt.new { |mpz| LibGMP.fdiv_q(mpz, self, other) }
  end

  def /(other : Int)
    check_division_by_zero other

    if other < 0
      -(self / other.abs)
    else
      BigInt.new { |mpz| LibGMP.fdiv_q_ui(mpz, self, other) }
    end
  end

  def %(other : BigInt)
    check_division_by_zero other

    BigInt.new { |mpz| LibGMP.fdiv_r(mpz, self, other) }
  end

  def %(other : Int)
    check_division_by_zero other

    BigInt.new { |mpz| LibGMP.fdiv_r_ui(mpz, self, other.abs) }
  end

  def ~
    BigInt.new { |mpz| LibGMP.com(mpz, self) }
  end

  def &(other : Int)
    BigInt.new { |mpz| LibGMP.and(mpz, self, other.to_big_i) }
  end

  def |(other : Int)
    BigInt.new { |mpz| LibGMP.ior(mpz, self, other.to_big_i) }
  end

  def ^(other : Int)
    BigInt.new { |mpz| LibGMP.xor(mpz, self, other.to_big_i) }
  end

  def >>(other : Int)
    BigInt.new { |mpz| LibGMP.fdiv_q_2exp(mpz, self, other) }
  end

  def <<(other : Int)
    BigInt.new { |mpz| LibGMP.mul_2exp(mpz, self, other) }
  end

  def **(other : Int)
    if other < 0
      raise ArgumentError.new("negative exponent isn't supported")
    end
    BigInt.new { |mpz| LibGMP.pow_ui(mpz, self, other) }
  end

  def inspect
    to_s
  end

  def inspect(io)
    to_s io
  end

  def to_s
    String.new(to_cstr)
  end

  def to_s(io)
    str = to_cstr
    io.write Slice.new(str, LibC.strlen(str))
  end

  def to_s(base : Int)
    raise "Invalid base #{base}" unless 2 <= base <= 36
    cstr = LibGMP.get_str(nil, base, self)
    String.new(cstr)
  end

  def digits
    ary = [] of Int32
    self.to_s.each_char { |c| ary << c - '0' }
    ary
  end

  def popcount
    LibGMP.popcount(self)
  end

  def to_i
    to_i32
  end

  def to_i8
    to_i64.to_i8
  end

  def to_i16
    to_i64.to_i16
  end

  def to_i32
    to_i64.to_i32
  end

  def to_i64
    LibGMP.get_si(self)
  end

  def to_u
    to_u32
  end

  def to_u8
    to_i64.to_u8
  end

  def to_u16
    to_i64.to_u16
  end

  def to_u32
    to_i64.to_u32
  end

  def to_u64
    to_i64.to_u64
  end

  def to_f
    to_f64
  end

  def to_f32
    to_f64.to_f32
  end

  def to_f64
    LibGMP.get_d(self)
  end

  def to_big_i
    self
  end

  private def check_division_by_zero(value)
    if value == 0
      raise DivisionByZero.new
    end
  end

  private def mpz
    pointerof(@mpz)
  end

  private def to_cstr
    LibGMP.get_str(nil, 10, mpz)
  end

  def to_unsafe
    mpz
  end
end

struct Int
  include Comparable(BigInt)

  def <=>(other : BigInt)
    -(other <=> self)
  end

  def +(other : BigInt)
    other + self
  end

  def -(other : BigInt)
    if self < 0
      -(abs + other)
    else
      # The line below segfault on linux 32 bits for a (yet) unknown reason:
      #
      #     BigInt.new { |mpz| LibGMP.ui_sub(mpz, self.to_u64, other) }
      #
      # So for now we do it a bit slower.
      to_big_i - other
    end
  end

  def *(other : BigInt)
    other * self
  end

  def /(other : BigInt)
    to_big_i / other
  end

  def %(other : BigInt)
    to_big_i % other
  end

  def to_big_i
    BigInt.new(self)
  end
end

struct Float
  include Comparable(BigInt)

  def <=>(other : BigInt)
    -(other <=> self)
  end

  def to_big_i
    BigInt.new(self)
  end
end

class String
  def to_big_i(base = 10)
    BigInt.new(self, base)
  end
end
