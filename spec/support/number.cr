require "spec/helpers/iterate"

# Helper methods to describe the behavior of numbers of different types
BUILTIN_NUMBER_TYPES =
  [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128, Float32, Float64]
BUILTIN_INTEGER_TYPES =
  [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128]
BUILTIN_INT_CONVERSIONS = {
  to_i: Int32, to_u: UInt32,
  to_i8: Int8, to_i16: Int16, to_i32: Int32, to_i64: Int64, to_i128: Int128,
  to_u8: UInt8, to_u16: UInt16, to_u32: UInt32, to_u64: UInt64, to_u128: UInt128,
}
BUILTIN_NUMBER_TYPES_LTE_64 =
  [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64]
BUILTIN_FLOAT_TYPES =
  [Float32, Float64]

macro it_can_convert_between(a_types, b_types)
  {% for a_type in a_types %}
    {% for b_type in b_types %}
      it "converts from {{a_type}} to {{b_type}}" do
        {{b_type}}.new({{a_type}}.new(1)).should be_a({{b_type}})
      end

      it "converts from {{b_type}} to {{a_type}}" do
        {{a_type}}.new({{b_type}}.new(1)).should be_a({{a_type}})
      end
    {% end %}
  {% end %}
end

macro it_initializes_from_value_to(number_type)
  it "initialize from value to {{number_type}}" do
    {{number_type}}.new(1).should be_a({{number_type}})
    {{number_type}}.new(1).should eq(1)

    {{number_type}}.new(1u32).should be_a({{number_type}})
    {{number_type}}.new(1u32).should eq(1)

    {{number_type}}.new(1.0).should be_a({{number_type}})
    {{number_type}}.new(1.0).should eq(1)
  end
end

macro it_unchecked_initializes_from_value_to(number_type)
  it "unchecked initialize from value to {{number_type}}" do
    {{number_type}}.new!(1).should be_a({{number_type}})
    {{number_type}}.new!(1).should eq(1)

    {{number_type}}.new!(1u32).should be_a({{number_type}})
    {{number_type}}.new!(1u32).should eq(1)

    {{number_type}}.new!(1.0).should be_a({{number_type}})
    {{number_type}}.new!(1.0).should eq(1)
  end
end

macro division_between_returns(a_types, b_types, result_type)
  {% for a_type in a_types %}
    {% for b_type in b_types %}
      it "division between {{a_type}} / {{b_type}} returns {{result_type}}" do
        r = {{a_type}}.new(1) / {{b_type}}.new(1)
        r.should be_a({{result_type}})
        r.should eq(1)
      end
    {% end %}
  {% end %}
end

macro floor_division_returns_lhs_type(a_types, b_types)
  {% for a_type in a_types %}
    {% for b_type in b_types %}
      it "floor_division {{a_type}} // {{b_type}} returns {{a_type}}" do
        r = {{a_type}}.new(5) // {{b_type}}.new(2)
        r.should be_a({{a_type}})
        r.should eq(2)
      end
    {% end %}
  {% end %}
end

# TODO test to_X conversions return types
# TODO test zero? comparisons
# TODO test <=> comparisons between types

private module HexFloatConverter(F, U)
  # Converts `str`, a hexadecimal floating-point literal, to an `F`. Truncates
  # all unused bits in the mantissa.
  def self.to_f(str : String) : F
    m = str.match(/^(-?)0x([0-9A-Fa-f]+)(?:\.([0-9A-Fa-f]+))?p([+-]?)([0-9]+)#{"_?f32" if F == Float32}$/).not_nil!

    total_bits = F == Float32 ? 32 : 64
    mantissa_bits = F::MANT_DIGITS - 1
    exponent_bias = F::MAX_EXP - 1

    is_negative = m[1] == "-"
    int_part = U.new(m[2], base: 16)
    frac = m[3]?.try(&.[0, (mantissa_bits + 3) // 4]) || "0"
    frac_part = U.new(frac, base: 16) << (mantissa_bits - frac.size * 4)
    exponent = m[5].to_i * (m[4] == "-" ? -1 : 1)

    if int_part > 1
      last_bit = U.zero
      while int_part > 1
        last_bit = frac_part & 1
        frac_part |= (U.new!(1) << mantissa_bits) if int_part & 1 != 0
        frac_part >>= 1
        int_part >>= 1
        exponent += 1
      end
      if last_bit != 0
        frac_part += 1
        if frac_part >= U.new!(1) << mantissa_bits
          frac_part = U.new!(0)
          int_part += 1
        end
      end
    elsif int_part == 0
      while int_part == 0
        frac_part <<= 1
        if frac_part >= U.new!(1) << mantissa_bits
          frac_part &= ~(U::MAX << mantissa_bits)
          int_part += 1
        end
        exponent -= 1
      end
    end

    exponent += exponent_bias
    if exponent >= exponent_bias * 2 + 1
      F::INFINITY * (is_negative ? -1 : 1)
    elsif exponent < -mantissa_bits
      F.zero * (is_negative ? -1 : 1)
    elsif exponent <= 0
      f = (frac_part >> (1 - exponent)) | (int_part << (mantissa_bits - 1 + exponent))
      f |= U.new!(1) << (total_bits - 1) if is_negative
      f.unsafe_as(F)
    else
      f = frac_part
      f |= U.new!(exponent) << mantissa_bits
      f |= U.new!(1) << (total_bits - 1) if is_negative
      f.unsafe_as(F)
    end
  end
end

def hexfloat_f64(str : String) : Float64
  HexFloatConverter(Float64, UInt64).to_f(str)
end

def hexfloat_f32(str : String) : Float32
  HexFloatConverter(Float32, UInt32).to_f(str)
end

macro hexfloat(str)
  {% raise "`str` must be a StringLiteral, not #{str.class_name}" unless str.is_a?(StringLiteral) %}
  {% if str.ends_with?("_f32") %}
    hexfloat_f32({{ str }})
  {% else %}
    hexfloat_f64({{ str }})
  {% end %}
end
