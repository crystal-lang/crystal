{% skip_file if flag?(:bits32) %}

require "spec"
require "big"
require "../../support/number"

private BIG_NUMBER_TYPES = [BigInt, BigFloat, BigDecimal, BigRational]

describe "Big* as numbers" do
  {% for number_type in BIG_NUMBER_TYPES %}
    it_initializes_from_value_to {{ number_type }}
  {% end %}

  it_can_convert_between({{ BIG_NUMBER_TYPES }}, {{ BIG_NUMBER_TYPES }})
  it_can_convert_between({{ BUILTIN_NUMBER_TYPES_LTE_64 }}, {{ BIG_NUMBER_TYPES }})
  it_can_convert_between({{ BIG_NUMBER_TYPES }}, {{ BUILTIN_NUMBER_TYPES_LTE_64 }})
  # TODO pending conversion between Int128

  floor_division_returns_lhs_type {{ BIG_NUMBER_TYPES }}, {{ BIG_NUMBER_TYPES }}
  floor_division_returns_lhs_type {{ BUILTIN_NUMBER_TYPES_LTE_64 }}, {{ BIG_NUMBER_TYPES }}
  floor_division_returns_lhs_type {{ BIG_NUMBER_TYPES }}, {{ BUILTIN_NUMBER_TYPES_LTE_64 }}
  # TODO pending cases between Int128

  division_between_returns {{ BUILTIN_NUMBER_TYPES }}, [BigInt, BigFloat], BigFloat
  division_between_returns [BigInt, BigFloat], {{ BUILTIN_NUMBER_TYPES }}, BigFloat
  division_between_returns [BigInt, BigFloat], [BigInt, BigFloat], BigFloat

  division_between_returns {{ BUILTIN_NUMBER_TYPES }}, [BigDecimal], BigDecimal
  division_between_returns [BigDecimal], {{ BUILTIN_NUMBER_TYPES }}, BigDecimal
  division_between_returns [BigDecimal], [BigInt, BigFloat, BigDecimal], BigDecimal
  division_between_returns [BigInt, BigFloat, BigDecimal], [BigDecimal], BigDecimal

  division_between_returns {{ BUILTIN_NUMBER_TYPES }}, [BigRational], BigRational
  division_between_returns [BigRational], {{ BUILTIN_NUMBER_TYPES }}, BigRational
  division_between_returns [BigRational], {{ BIG_NUMBER_TYPES }}, BigRational
  division_between_returns {{ BIG_NUMBER_TYPES }}, [BigRational], BigRational
end
