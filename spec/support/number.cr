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
BUILTIN_NUMBER_SUFFIXES = {
  Int8    => "i8",
  Int16   => "i16",
  Int32   => "i32",
  Int64   => "i64",
  Int128  => "i128",
  UInt8   => "u8",
  UInt16  => "u16",
  UInt32  => "u32",
  UInt64  => "u64",
  UInt128 => "u128",
  Float32 => "f32",
  Float64 => "f64",
}

macro it_can_convert_between(a_types, b_types)
  {% for a_type in a_types %}
    {% for b_type in b_types %}
      it "converts from {{ a_type }} to {{ b_type }}" do
        {{ b_type }}.new({{ a_type }}.new(1)).should be_a({{ b_type }})
      end

      it "converts from {{ b_type }} to {{ a_type }}" do
        {{ a_type }}.new({{ b_type }}.new(1)).should be_a({{ a_type }})
      end
    {% end %}
  {% end %}
end

macro it_initializes_from_value_to(number_type)
  it "initialize from value to {{ number_type }}" do
    {{ number_type }}.new(1).should be_a({{ number_type }})
    {{ number_type }}.new(1).should eq(1)

    {{ number_type }}.new(1u32).should be_a({{ number_type }})
    {{ number_type }}.new(1u32).should eq(1)

    {{ number_type }}.new(1.0).should be_a({{ number_type }})
    {{ number_type }}.new(1.0).should eq(1)
  end
end

macro it_unchecked_initializes_from_value_to(number_type)
  it "unchecked initialize from value to {{ number_type }}" do
    {{ number_type }}.new!(1).should be_a({{ number_type }})
    {{ number_type }}.new!(1).should eq(1)

    {{ number_type }}.new!(1u32).should be_a({{ number_type }})
    {{ number_type }}.new!(1u32).should eq(1)

    {{ number_type }}.new!(1.0).should be_a({{ number_type }})
    {{ number_type }}.new!(1.0).should eq(1)
  end
end

macro division_between_returns(a_types, b_types, result_type)
  {% for a_type in a_types %}
    {% for b_type in b_types %}
      it "division between {{ a_type }} / {{ b_type }} returns {{ result_type }}" do
        r = {{ a_type }}.new(1) / {{ b_type }}.new(1)
        r.should be_a({{ result_type }})
        r.should eq(1)
      end
    {% end %}
  {% end %}
end

macro floor_division_returns_lhs_type(a_types, b_types)
  {% for a_type in a_types %}
    {% for b_type in b_types %}
      it "floor_division {{ a_type }} // {{ b_type }} returns {{ a_type }}" do
        r = {{ a_type }}.new(5) // {{ b_type }}.new(2)
        r.should be_a({{ a_type }})
        r.should eq(2)
      end
    {% end %}
  {% end %}
end

# TODO test to_X conversions return types
# TODO test zero? comparisons
# TODO test <=> comparisons between types

# Calls either `Float64.parse_hexfloat` or `Float32.parse_hexfloat`. The default
# is `Float64` unless *str* ends with `_f32`, in which case that suffix is
# stripped and `Float32` is chosen.
macro hexfloat(str)
  {% raise "`str` must be a StringLiteral, not #{str.class_name}" unless str.is_a?(StringLiteral) %}
  {% if str.ends_with?("_f32") %}
    ::Float32.parse_hexfloat({{ str[0...-4] }})
  {% else %}
    ::Float64.parse_hexfloat({{ str }})
  {% end %}
end

# See also: https://github.com/crystal-lang/crystal/issues/15192
lib LibC
  {% if flag?(:win32) %}
    FE_TONEAREST  = 0x00000000
    FE_DOWNWARD   = 0x00000100
    FE_UPWARD     = 0x00000200
    FE_TOWARDZERO = 0x00000300
  {% else %}
    FE_TONEAREST  = 0x00000000
    FE_DOWNWARD   = 0x00000400
    FE_UPWARD     = 0x00000800
    FE_TOWARDZERO = 0x00000C00
  {% end %}

  fun fegetround : Int
  fun fesetround(round : Int) : Int
end

def with_hardware_rounding_mode(mode, &)
  old_mode = LibC.fegetround
  LibC.fesetround(mode)
  yield ensure LibC.fesetround(old_mode)
end

def each_hardware_rounding_mode(&)
  {% for mode in %w(FE_TONEAREST FE_DOWNWARD FE_UPWARD FE_TOWARDZERO) %}
    with_hardware_rounding_mode(LibC::{{ mode.id }}) do
      yield LibC::{{ mode.id }}, {{ mode }}
    end
  {% end %}
end
