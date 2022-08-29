require "spec"

# TODO: merge these helpers with #10913
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
