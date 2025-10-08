module Float::FastFloat
  @[Flags]
  enum CharsFormat
    Scientific = 1 << 0
    Fixed      = 1 << 2
    Hex        = 1 << 3
    NoInfnan   = 1 << 4
    JsonFmt    = 1 << 5
    FortranFmt = 1 << 6

    # RFC 8259: https://datatracker.ietf.org/doc/html/rfc8259#section-6
    Json = JsonFmt | Fixed | Scientific | NoInfnan

    # Extension of RFC 8259 where, e.g., "inf" and "nan" are allowed.
    JsonOrInfnan = JsonFmt | Fixed | Scientific

    Fortran = FortranFmt | Fixed | Scientific
    General = Fixed | Scientific
  end

  # NOTE(crystal): uses `Errno` to represent C++'s `std::errc`
  record FromCharsResultT(UC), ptr : UC*, ec : Errno

  alias FromCharsResult = FromCharsResultT(UInt8)

  record ParseOptionsT(UC), format : CharsFormat = :general, decimal_point : UC = 0x2E # '.'.ord

  alias ParseOptions = ParseOptionsT(UInt8)

  # rust style `try!()` macro, or `?` operator
  macro fastfloat_try(x)
    unless {{ x }}
      return false
    end
  end

  # Compares two ASCII strings in a case insensitive manner.
  def self.fastfloat_strncasecmp(input1 : UC*, input2 : UC*, length : Int) : Bool forall UC
    running_diff = 0_u8
    length.times do |i|
      running_diff |= input1[i].to_u8! ^ input2[i].to_u8!
    end
    running_diff.in?(0_u8, 32_u8)
  end

  record Value128, low : UInt64, high : UInt64 do
    def self.new(x : UInt128) : self
      new(low: x.to_u64!, high: x.unsafe_shr(64).to_u64!)
    end
  end

  struct AdjustedMantissa
    property mantissa : UInt64
    property power2 : Int32

    def initialize(@mantissa : UInt64 = 0, @power2 : Int32 = 0)
    end
  end

  INVALID_AM_BIAS = -0x8000

  CONSTANT_55555 = 3125_u64

  module BinaryFormat(T, EquivUint)
  end

  struct BinaryFormat_Float64
    include BinaryFormat(Float64, UInt64)

    POWERS_OF_TEN = [
      1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11,
      1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22,
    ]

    # Largest integer value v so that (5**index * v) <= 1<<53.
    # 0x20000000000000 == 1 << 53
    MAX_MANTISSA = [
      0x20000000000000_u64,
      0x20000000000000_u64.unsafe_div(5),
      0x20000000000000_u64.unsafe_div(5 * 5),
      0x20000000000000_u64.unsafe_div(5 * 5 * 5),
      0x20000000000000_u64.unsafe_div(5 * 5 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * 5 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * 5 * 5 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * 5 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * 5 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * 5 * 5 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * 5 * 5 * 5),
      0x20000000000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * CONSTANT_55555 * 5 * 5 * 5 * 5),
    ]

    def min_exponent_fast_path : Int32
      -22
    end

    def mantissa_explicit_bits : Int32
      52
    end

    def max_exponent_round_to_even : Int32
      23
    end

    def min_exponent_round_to_even : Int32
      -4
    end

    def minimum_exponent : Int32
      -1023
    end

    def infinite_power : Int32
      0x7FF
    end

    def sign_index : Int32
      63
    end

    def max_exponent_fast_path : Int32
      22
    end

    def max_mantissa_fast_path : UInt64
      0x20000000000000_u64
    end

    def max_mantissa_fast_path(power : Int64) : UInt64
      # caller is responsible to ensure that
      # power >= 0 && power <= 22
      MAX_MANTISSA.unsafe_fetch(power)
    end

    def exact_power_of_ten(power : Int64) : Float64
      POWERS_OF_TEN.unsafe_fetch(power)
    end

    def largest_power_of_ten : Int32
      308
    end

    def smallest_power_of_ten : Int32
      -342
    end

    def max_digits : Int32
      769
    end

    def exponent_mask : EquivUint
      0x7FF0000000000000_u64
    end

    def mantissa_mask : EquivUint
      0x000FFFFFFFFFFFFF_u64
    end

    def hidden_bit_mask : EquivUint
      0x0010000000000000_u64
    end
  end

  struct BinaryFormat_Float32
    include BinaryFormat(Float32, UInt32)

    POWERS_OF_TEN = [
      1e0f32, 1e1f32, 1e2f32, 1e3f32, 1e4f32, 1e5f32, 1e6f32, 1e7f32, 1e8f32, 1e9f32, 1e10f32,
    ]

    # Largest integer value v so that (5**index * v) <= 1<<24.
    # 0x1000000 == 1<<24
    MAX_MANTISSA = [
      0x1000000_u64,
      0x1000000_u64.unsafe_div(5),
      0x1000000_u64.unsafe_div(5 * 5),
      0x1000000_u64.unsafe_div(5 * 5 * 5),
      0x1000000_u64.unsafe_div(5 * 5 * 5 * 5),
      0x1000000_u64.unsafe_div(CONSTANT_55555),
      0x1000000_u64.unsafe_div(CONSTANT_55555 * 5),
      0x1000000_u64.unsafe_div(CONSTANT_55555 * 5 * 5),
      0x1000000_u64.unsafe_div(CONSTANT_55555 * 5 * 5 * 5),
      0x1000000_u64.unsafe_div(CONSTANT_55555 * 5 * 5 * 5 * 5),
      0x1000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555),
      0x1000000_u64.unsafe_div(CONSTANT_55555 * CONSTANT_55555 * 5),
    ]

    def min_exponent_fast_path : Int32
      -10
    end

    def mantissa_explicit_bits : Int32
      23
    end

    def max_exponent_round_to_even : Int32
      10
    end

    def min_exponent_round_to_even : Int32
      -17
    end

    def minimum_exponent : Int32
      -127
    end

    def infinite_power : Int32
      0xFF
    end

    def sign_index : Int32
      31
    end

    def max_exponent_fast_path : Int32
      10
    end

    def max_mantissa_fast_path : UInt64
      0x1000000_u64
    end

    def max_mantissa_fast_path(power : Int64) : UInt64
      # caller is responsible to ensure that
      # power >= 0 && power <= 10
      MAX_MANTISSA.unsafe_fetch(power)
    end

    def exact_power_of_ten(power : Int64) : Float32
      POWERS_OF_TEN.unsafe_fetch(power)
    end

    def largest_power_of_ten : Int32
      38
    end

    def smallest_power_of_ten : Int32
      -64
    end

    def max_digits : Int32
      114
    end

    def exponent_mask : EquivUint
      0x7F800000_u32
    end

    def mantissa_mask : EquivUint
      0x007FFFFF_u32
    end

    def hidden_bit_mask : EquivUint
      0x00800000_u32
    end
  end

  module BinaryFormat(T, EquivUint)
    # NOTE(crystal): returns the new *value* by value
    def to_float(negative : Bool, am : AdjustedMantissa) : T
      word = EquivUint.new!(am.mantissa)
      word |= EquivUint.new!(am.power2).unsafe_shl(mantissa_explicit_bits)
      word |= EquivUint.new!(negative ? 1 : 0).unsafe_shl(sign_index)
      word.unsafe_as(T)
    end
  end

  def self.int_cmp_zeros(uc : UC.class) : UInt64 forall UC
    case sizeof(UC)
    when 1
      0x3030303030303030_u64
    when 2
      0x0030003000300030_u64
    else
      0x0000003000000030_u64
    end
  end

  def self.int_cmp_len(uc : UC.class) : Int32 forall UC
    sizeof(UInt64).unsafe_div(sizeof(UC))
  end
end
