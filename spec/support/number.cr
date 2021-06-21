require "spec/helpers/iterate"

# Helper methods to describe the behavior of numbers of different types
{% if flag?(:darwin) %}
  BUILTIN_NUMBER_TYPES =
    [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128, Float32, Float64]
  BUILTIN_INTEGER_TYPES =
    [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128]
  BUILTIN_INTEGER_TYPES_128 =
    [Int128, UInt128]
{% else %}
  BUILTIN_NUMBER_TYPES =
    [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64]
  BUILTIN_INTEGER_TYPES =
    [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64]
  BUILTIN_INTEGER_TYPES_128 =
    [] of Int.class
{% end %}
BUILTIN_NUMBER_TYPES_LTE_64 =
  [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64]
BUILTIN_INTEGER_TYPES_LTE_64 =
  [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64]
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
