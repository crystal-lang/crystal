private macro __float_impl(name, from, to)
  {% n = from.stringify.gsub(/^.*?(\d+)$/, "\\1").to_i %}
  {% to_n = to.stringify.gsub(/^.*?(\d+)$/, "\\1").to_i %}
  {% signed = from.stringify.starts_with?("Int") %}
  {% raw = "UInt#{to_n}".id %}

  # :nodoc:
  # Ported from https://github.com/llvm/llvm-project/tree/82b74363a943b570c4ee7799d5f3ee4b3e7163a5/compiler-rt/lib/builtins
  fun {{ name }}(a : {{ from }}) : {{ to }}
    if a == 0
      return {{ to }}.new!(0)
    end
    {% if signed %}
      s = a.unsafe_shr({{ n - 1 }})
      a = (a ^ s) &- s
    {% end %}
    sd = {{ raw }}.new!({{ n }}) &- a.leading_zeros_count # number of significant digits
    e = sd &- 1                                       # exponent
    if sd > {{ to }}::MANT_DIGITS
      #  start: 0000000000000000000001xxxxxxxxxxxxxxxxxxxxxxPQxxxxxxxxxxxxxxxxxx
      # finish: 000000000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxPQR
      #                                               12345678901234567890123456
      # 1 = msb 1 bit
      # P = bit MANT_DIGITS-1 bits to the right of 1
      # Q = bit MANT_DIGITS bits to the right of 1
      # R = "or" of all bits to the right of Q
      if sd == {{ to }}::MANT_DIGITS &+ 1
        a = a.unsafe_shl(1)
      elsif sd == {{ to }}::MANT_DIGITS &+ 2
        # do nothing
      else
        a2 = (a & UInt{{ n }}::MAX.unsafe_shr(({{ n }} &+ {{ to }}::MANT_DIGITS &+ 2) &- sd)) != 0
        a = {{ from }}.new!(UInt{{ n }}.new!(a).unsafe_shr(sd &- ({{ to }}::MANT_DIGITS &+ 2)))
        a |= 1 if a2
      end
      # finish:
      a |= 1 if (a & 4) != 0 # Or P into R
      a &+= 1                # round - this step may add a significant bit
      a = a.unsafe_shr(2)    # dump Q and R
      # a is now rounded to MANT_DIGITS or MANT_DIGITS+1 bits
      if a & {{ from }}.new!(1).unsafe_shl({{ to }}::MANT_DIGITS) != 0
        a = a.unsafe_shr(1)
        e &+= 1
      end
      # a is now rounded to MANT_DIGITS bits
    else
      a = a.unsafe_shl({{ to }}::MANT_DIGITS &- sd)
      # a is now rounded to MANT_DIGITS bits
    end
    fb = {% if signed %} ({{ raw }}.new!(1).unsafe_shl({{ to_n - 1 }}) & s) | {% end %} # sign
          (e &+ {{ to }}::MAX_EXP &- 1).unsafe_shl({{ to }}::MANT_DIGITS &- 1) |        # exponent
          (a & ~({{ raw }}::MAX.unsafe_shl({{ to }}::MANT_DIGITS &- 1)))                # mantissa
    fb.unsafe_as({{ to }})
  end
end

__float_impl(__floattidf, Int128, Float64)
__float_impl(__floattisf, Int128, Float32)
__float_impl(__floatuntidf, UInt128, Float64)
__float_impl(__floatuntisf, UInt128, Float32)
