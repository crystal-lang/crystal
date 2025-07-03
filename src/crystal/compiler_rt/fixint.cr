private macro __fixint_impl(name, from, to)
  {% n = from.stringify.gsub(/^.*?(\d+)$/, "\\1").to_i %}
  {% to_n = to.stringify.gsub(/^.*?(\d+)$/, "\\1").to_i %}
  {% signed = to.stringify.starts_with?("Int") %}

  # :nodoc:
  # Ported from https://github.com/llvm/llvm-project/tree/82b74363a943b570c4ee7799d5f3ee4b3e7163a5/compiler-rt/lib/builtins
  fun {{name}}(a : {{from}}) : {{to}}
    # Break a into sign, exponent, significand parts.
    a_rep = a.unsafe_as(UInt{{n}})
    a_abs = a_rep & UInt{{n}}::MAX.unsafe_shr(1)
    sign = a_rep & (UInt{{n}}.new!(1).unsafe_shl({{n - 1}})) != 0 ? -1 : 1
    significand_bits = {{from}}::MANT_DIGITS &- 1
    exponent = a_abs.unsafe_shr(significand_bits).to_i! &- ({{from}}::MAX_EXP &- 1)
    implicit_bit = UInt{{n}}.new!(1).unsafe_shl(significand_bits)
    significand = (a_abs & (implicit_bit &- 1)) | implicit_bit

    {% if signed %}
      # If exponent is negative, the result is zero.
      if exponent < 0
        return {{to}}.new!(0)
      end

      # If the value is too large for the integer type, saturate.
      if exponent >= {{to_n}}
        return sign == 1 ? {{to}}::MAX : {{to}}::MIN
      end

      # If 0 <= exponent < significandBits, right shift to get the result.
      # Otherwise, shift left. (`#<<` handles this)
      {{to}}.new!(sign) * ({{to}}.new!(significand) << (exponent &- significand_bits))
    {% else %}
      # If either the value or the exponent is negative, the result is zero.
      if sign == -1 || exponent < 0
        return {{to}}.new!(0)
      end

      # If the value is too large for the integer type, saturate.
      if exponent >= {{to_n}}
        return {{to}}::MAX
      end

      # If 0 <= exponent < significandBits, right shift to get the result.
      # Otherwise, shift left. (`#<<` handles this)
      {{to}}.new!(significand) << (exponent &- significand_bits)
    {% end %}
  end
end

__fixint_impl(__fixdfti, Float64, Int128)
__fixint_impl(__fixsfti, Float32, Int128)
__fixint_impl(__fixunsdfti, Float64, UInt128)
__fixint_impl(__fixunssfti, Float32, UInt128)
