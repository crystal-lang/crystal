require "./lib_gmp"

struct BigInt < Int
  include Comparable(SignedInt)
  include Comparable(UnsignedInt)
  include Comparable(BigInt)

  def initialize
    LibGMP.init(out @mpz)
  end

  def initialize(str : String)
    LibGMP.init_set_str(out @mpz, str, 10)
  end

  def initialize(num : SignedInt)
    LibGMP.init_set_si(out @mpz, num.to_i64)
  end

  def initialize(num : UnsignedInt)
    LibGMP.init_set_ui(out @mpz, num.to_u64)
  end

  def initialize(@mpz : MPZ)
  end

  def self.new
    LibGMP.init(out mpz)
    yield pointerof(mpz)
    new(mpz)
  end

  def <=>(other : BigInt)
    LibGMP.cmp(mpz, other)
  end

  def <=>(other : SignedInt)
    LibGMP.cmp_si(mpz, other.to_i64)
  end

  def <=>(other : UnsignedInt)
    LibGMP.cmp_ui(mpz, other.to_u64)
  end

  def +(other : BigInt)
    BigInt.new { |mpz| LibGMP.add(mpz, self, other) }
  end

  def +(other : Int)
    if other < 0
      self - other.abs
    else
      BigInt.new { |mpz| LibGMP.add_ui(mpz, self, other.to_u64) }
    end
  end

  def -(other : BigInt)
    BigInt.new { |mpz| LibGMP.sub(mpz, self, other) }
  end

  def -(other : Int)
    if other < 0
      self + other.abs
    else
      BigInt.new { |mpz| LibGMP.sub_ui(mpz, self, other.to_u64) }
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

  def *(other : SignedInt)
    BigInt.new { |mpz| LibGMP.mul_si(mpz, self, other.to_i64) }
  end

  def *(other : UnsignedInt)
    BigInt.new { |mpz| LibGMP.mul_ui(mpz, self, other.to_u64) }
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
      BigInt.new { |mpz| LibGMP.fdiv_q_ui(mpz, self, other.to_u64) }
    end
  end

  def %(other : BigInt)
    check_division_by_zero other

    BigInt.new { |mpz| LibGMP.fdiv_r(mpz, self, other) }
  end

  def %(other : Int)
    check_division_by_zero other

    BigInt.new { |mpz| LibGMP.fdiv_r_ui(mpz, self, other.abs.to_u64) }
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
    BigInt.new { |mpz| LibGMP.fdiv_q_2exp(mpz, self, other.to_i32) }
  end

  def <<(other : Int)
    BigInt.new { |mpz| LibGMP.mul_2exp(mpz, self, other.to_i32) }
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

  def digits
    ary = [] of Int32
    self.to_s.each_char { |c| ary << c - '0' }
    ary
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
