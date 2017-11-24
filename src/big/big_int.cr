require "c/string"

# A `BigInt` can represent arbitrarily large integers.
#
# It is implemented under the hood with [GMP](https://gmplib.org/).
struct BigInt < Int
  include Comparable(Int::Signed)
  include Comparable(Int::Unsigned)
  include Comparable(BigInt)
  include Comparable(Float)

  # Creates a `BigInt` with the value zero.
  #
  # ```
  # require "big"
  # BigInt.new # => 0
  # ```
  def initialize
    LibGMP.init(out @mpz)
  end

  # Creates a `BigInt` with the value denoted by *str* in the given *base*.
  #
  # Raises `ArgumentError` if the string doesn't denote a valid integer.
  #
  # ```
  # BigInt.new("123456789123456789123456789123456789") # => 123456789123456789123456789123456789
  # BigInt.new("1234567890ABCDEF", base: 16)           # => 1311768467294899695
  # ```
  def initialize(str : String, base = 10)
    err = LibGMP.init_set_str(out @mpz, str, base)
    if err == -1
      raise ArgumentError.new("Invalid BigInt: #{str}")
    end
  end

  # Creates a `BigInt` from the given *num*.
  def initialize(num : Int::Signed)
    if LibC::Long::MIN <= num <= LibC::Long::MAX
      LibGMP.init_set_si(out @mpz, num)
    else
      LibGMP.init_set_str(out @mpz, num.to_s, 10)
    end
  end

  # ditto
  def initialize(num : Int::Unsigned)
    if num <= LibC::ULong::MAX
      LibGMP.init_set_ui(out @mpz, num)
    else
      LibGMP.init_set_str(out @mpz, num.to_s, 10)
    end
  end

  # ditto
  def initialize(num : Float)
    LibGMP.init_set_d(out @mpz, num)
  end

  # Returns *num*. Useful for generic code that does `T.new(...)` with `T`
  # being a `Number`.
  def self.new(num : BigInt)
    num
  end

  # :nodoc:
  def initialize(@mpz : LibGMP::MPZ)
  end

  # :nodoc:
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

  def +(other : BigInt) : BigInt
    BigInt.new { |mpz| LibGMP.add(mpz, self, other) }
  end

  def +(other : Int) : BigInt
    if other < 0
      self - other.abs
    elsif other <= LibGMP::ULong::MAX
      BigInt.new { |mpz| LibGMP.add_ui(mpz, self, other) }
    else
      self + other.to_big_i
    end
  end

  def -(other : BigInt) : BigInt
    BigInt.new { |mpz| LibGMP.sub(mpz, self, other) }
  end

  def -(other : Int) : BigInt
    if other < 0
      self + other.abs
    elsif other <= LibGMP::ULong::MAX
      BigInt.new { |mpz| LibGMP.sub_ui(mpz, self, other) }
    else
      self - other.to_big_i
    end
  end

  def - : BigInt
    BigInt.new { |mpz| LibGMP.neg(mpz, self) }
  end

  def abs : BigInt
    BigInt.new { |mpz| LibGMP.abs(mpz, self) }
  end

  def *(other : BigInt) : BigInt
    BigInt.new { |mpz| LibGMP.mul(mpz, self, other) }
  end

  def *(other : LibGMP::IntPrimitiveSigned) : BigInt
    BigInt.new { |mpz| LibGMP.mul_si(mpz, self, other) }
  end

  def *(other : LibGMP::IntPrimitiveUnsigned) : BigInt
    BigInt.new { |mpz| LibGMP.mul_ui(mpz, self, other) }
  end

  def *(other : Int) : BigInt
    self * other.to_big_i
  end

  def /(other : Int) : BigInt
    check_division_by_zero other

    if other < 0
      (-self).unsafe_floored_div(-other)
    else
      unsafe_floored_div(other)
    end
  end

  def tdiv(other : Int) : BigInt
    check_division_by_zero other

    unsafe_truncated_div(other)
  end

  def unsafe_floored_div(other : BigInt) : BigInt
    BigInt.new { |mpz| LibGMP.fdiv_q(mpz, self, other) }
  end

  def unsafe_floored_div(other : Int) : BigInt
    if LibGMP::ULong == UInt32 && (other < Int32::MIN || other > UInt32::MAX)
      unsafe_floored_div(other.to_big_i)
    elsif other < 0
      -BigInt.new { |mpz| LibGMP.fdiv_q_ui(mpz, self, other.abs) }
    else
      BigInt.new { |mpz| LibGMP.fdiv_q_ui(mpz, self, other) }
    end
  end

  def unsafe_truncated_div(other : BigInt) : BigInt
    BigInt.new { |mpz| LibGMP.tdiv_q(mpz, self, other) }
  end

  def unsafe_truncated_div(other : Int) : BigInt
    if LibGMP::ULong == UInt32 && (other < Int32::MIN || other > UInt32::MAX)
      unsafe_truncated_div(other.to_big_i)
    elsif other < 0
      -BigInt.new { |mpz| LibGMP.tdiv_q_ui(mpz, self, other.abs) }
    else
      BigInt.new { |mpz| LibGMP.tdiv_q_ui(mpz, self, other) }
    end
  end

  def %(other : Int) : BigInt
    check_division_by_zero other

    if other < 0
      -(-self).unsafe_floored_mod(-other)
    else
      unsafe_floored_mod(other)
    end
  end

  def remainder(other : Int) : BigInt
    check_division_by_zero other

    unsafe_truncated_mod(other)
  end

  def divmod(number : BigInt)
    check_division_by_zero number

    unsafe_floored_divmod(number)
  end

  def divmod(number : LibGMP::ULong)
    check_division_by_zero number
    unsafe_floored_divmod(number)
  end

  def divmod(number : Int::Signed)
    check_division_by_zero number
    if number > 0 && number <= LibC::Long::MAX
      unsafe_floored_divmod(LibGMP::ULong.new(number))
    else
      divmod(number.to_big_i)
    end
  end

  def divmod(number : Int::Unsigned)
    check_division_by_zero number
    if number <= LibC::ULong::MAX
      unsafe_floored_divmod(LibGMP::ULong.new(number))
    else
      divmod(number.to_big_i)
    end
  end

  def unsafe_floored_mod(other : BigInt) : BigInt
    BigInt.new { |mpz| LibGMP.fdiv_r(mpz, self, other) }
  end

  def unsafe_floored_mod(other : Int) : BigInt
    if (other < LibGMP::Long::MIN || other > LibGMP::ULong::MAX)
      unsafe_floored_mod(other.to_big_i)
    elsif other < 0
      -BigInt.new { |mpz| LibGMP.fdiv_r_ui(mpz, self, other.abs) }
    else
      BigInt.new { |mpz| LibGMP.fdiv_r_ui(mpz, self, other) }
    end
  end

  def unsafe_truncated_mod(other : BigInt) : BigInt
    BigInt.new { |mpz| LibGMP.tdiv_r(mpz, self, other) }
  end

  def unsafe_truncated_mod(other : LibGMP::IntPrimitive) : BigInt
    BigInt.new { |mpz| LibGMP.tdiv_r_ui(mpz, self, other.abs) }
  end

  def unsafe_truncated_mod(other : Int) : BigInt
    BigInt.new { |mpz| LibGMP.tdiv_r_ui(mpz, self, other.abs.to_big_i) }
  end

  def unsafe_floored_divmod(number : BigInt)
    the_q = BigInt.new
    the_r = BigInt.new { |r| LibGMP.fdiv_qr(the_q, r, self, number) }
    {the_q, the_r}
  end

  def unsafe_floored_divmod(number : LibGMP::ULong)
    the_q = BigInt.new
    the_r = BigInt.new { |r| LibGMP.fdiv_qr_ui(the_q, r, self, number) }
    {the_q, the_r}
  end

  def unsafe_truncated_divmod(number : BigInt)
    the_q = BigInt.new
    the_r = BigInt.new { |r| LibGMP.tdiv_qr(the_q, r, self, number) }
    {the_q, the_r}
  end

  def unsafe_truncated_divmod(number : LibGMP::ULong)
    the_q = BigInt.new
    the_r = BigInt.new { |r| LibGMP.tdiv_qr_ui(the_q, r, self, number) }
    {the_q, the_r}
  end

  def ~ : BigInt
    BigInt.new { |mpz| LibGMP.com(mpz, self) }
  end

  def &(other : Int) : BigInt
    BigInt.new { |mpz| LibGMP.and(mpz, self, other.to_big_i) }
  end

  def |(other : Int) : BigInt
    BigInt.new { |mpz| LibGMP.ior(mpz, self, other.to_big_i) }
  end

  def ^(other : Int) : BigInt
    BigInt.new { |mpz| LibGMP.xor(mpz, self, other.to_big_i) }
  end

  def >>(other : Int) : BigInt
    BigInt.new { |mpz| LibGMP.fdiv_q_2exp(mpz, self, other) }
  end

  def <<(other : Int) : BigInt
    BigInt.new { |mpz| LibGMP.mul_2exp(mpz, self, other) }
  end

  def **(other : Int) : BigInt
    if other < 0
      raise ArgumentError.new("Negative exponent isn't supported")
    end
    BigInt.new { |mpz| LibGMP.pow_ui(mpz, self, other) }
  end

  def gcd(other : BigInt) : BigInt
    BigInt.new { |mpz| LibGMP.gcd(mpz, self, other) }
  end

  def gcd(other : Int) : Int
    result = LibGMP.gcd_ui(nil, self, other.abs.to_u64)
    result == 0 ? self : result
  end

  def lcm(other : BigInt) : BigInt
    BigInt.new { |mpz| LibGMP.lcm(mpz, self, other) }
  end

  def lcm(other : Int) : BigInt
    BigInt.new { |mpz| LibGMP.lcm_ui(mpz, self, other.abs.to_u64) }
  end

  def inspect(io)
    to_s io
    io << "_big_i"
  end

  # TODO: improve this
  def_hash to_u64

  # Returns a string representation of self.
  #
  # ```
  # BigInt.new("123456789101101987654321").to_s # => 123456789101101987654321
  # ```
  def to_s
    String.new(to_cstr)
  end

  # ditto
  def to_s(io)
    str = to_cstr
    io.write_utf8 Slice.new(str, LibC.strlen(str))
  end

  # Returns a string containing the representation of big radix base (2 through 36).
  #
  # ```
  # BigInt.new("123456789101101987654321").to_s(8)  # => "32111154373025463465765261"
  # BigInt.new("123456789101101987654321").to_s(16) # => "1a249b1f61599cd7eab1"
  # BigInt.new("123456789101101987654321").to_s(36) # => "k3qmt029k48nmpd"
  # ```
  def to_s(base : Int)
    raise "Invalid base #{base}" unless 2 <= base <= 36
    cstr = LibGMP.get_str(nil, base, self)
    String.new(cstr)
  end

  def digits : Array(Int32)
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
    to_i32.to_i8
  end

  def to_i16
    to_i32.to_i16
  end

  def to_i32
    LibGMP.get_si(self).to_i32
  end

  def to_i64
    if LibGMP::Long == Int64 || (self <= Int32::MAX && self >= Int32::MIN)
      LibGMP.get_si(self).to_i64
    else
      to_s.to_i64
    end
  end

  def to_u
    to_u32
  end

  def to_u8
    to_u32.to_u8
  end

  def to_u16
    to_u32.to_u16
  end

  def to_u32
    LibGMP.get_ui(self).to_u32
  end

  def to_u64
    if LibGMP::ULong == UInt64 || (self <= UInt32::MAX && self >= UInt32::MIN)
      LibGMP.get_ui(self).to_u64
    else
      to_s.to_u64
    end
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

  def to_big_f
    BigFloat.new { |mpf| LibGMP.mpf_set_z(mpf, mpz) }
  end

  def clone
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

  def +(other : BigInt) : BigInt
    other + self
  end

  def -(other : BigInt) : BigInt
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

  def *(other : BigInt) : BigInt
    other * self
  end

  def /(other : BigInt) : BigInt
    to_big_i / other
  end

  def %(other : BigInt) : BigInt
    to_big_i % other
  end

  def gcm(other : BigInt) : Int
    other.gcm(self)
  end

  def lcm(other : BigInt) : BigInt
    other.lcm(self)
  end

  # Returns a `BigInt` representing this integer.
  def to_big_i : BigInt
    BigInt.new(self)
  end
end

struct Float
  include Comparable(BigInt)

  def <=>(other : BigInt)
    -(other <=> self)
  end

  # Returns a `BigInt` representing this float (rounded using `floor`).
  def to_big_i : BigInt
    BigInt.new(self)
  end
end

class String
  # Returns a `BigInt` from this string, in the given *base*.
  #
  # Raises `ArgumentError` if this string doesn't denote a valid integer.
  def to_big_i(base = 10) : BigInt
    BigInt.new(self, base)
  end
end

module Math
  def sqrt(value : BigInt)
    sqrt(value.to_big_f)
  end
end

# :nodoc:
struct Crystal::Hasher
  private HASH_MODULUS_INT_P = BigInt.new((1_u64 << HASH_BITS) - 1)
  private HASH_MODULUS_INT_N = -BigInt.new((1_u64 << HASH_BITS) - 1)

  def int(value : BigInt)
    # it should calculate `remainder(HASH_MODULUS)`
    if LibGMP::ULong == UInt64
      v = LibGMP.tdiv_ui(value, HASH_MODULUS).to_i64
      value < 0 ? -v : v
    elsif value >= HASH_MODULUS_INT_P || value <= HASH_MODULUS_INT_N
      value.unsafe_truncated_mod(HASH_MODULUS_INT_P).to_i64
    else
      value.to_i64
    end
  end
end
