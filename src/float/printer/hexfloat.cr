module Float::Printer::Hexfloat(F, U)
  # IEEE defines the following grammar:
  #
  # ```
  # sign            = /[+−]/
  # digit           = /[0123456789]/
  # hexDigit        = /[0123456789abcdefABCDEF]/
  # hexExpIndicator = /[Pp]/
  # hexIndicator    = /0[Xx]/
  # hexSignificand  = /#{hexDigit}*\.#{hexDigit}+|#{hexDigit}+\.|#{hexDigit}+/
  # decExponent     = /#{hexExpIndicator}#{sign}?#{digit}+/
  # hexSequence     = /#{sign}?#{hexIndicator}#{hexSignificand}#{decExponent}/
  #                 = /[+−]?0[Xx](?:[0-9A-Fa-f]*\.[0-9A-Fa-f]+|[0-9A-Fa-f]+\.?)[Pp][+−]?[0-9]+/
  # ```
  def self.to_f(str : String, &)
    ptr = str.to_unsafe
    finish = ptr + str.bytesize

    # TODO: this portion is probably common with other float parsers too
    ptr, negative = parse_sign(ptr, finish)
    str_bytes = Slice.new(ptr, finish - ptr)
    if eq_case_insensitive?(str_bytes, "inf") || eq_case_insensitive?(str_bytes, "infinity")
      return F::INFINITY * (negative ? -1 : 1)
    elsif eq_case_insensitive?(str_bytes, "nan")
      return F::NAN
    end

    check_ch '0'
    check_ch 'x', 'X'

    mantissa = U.zero
    mantissa_max = ~(U::MAX << (F::MANT_DIGITS + 1))
    trailing_nonzero = false
    exp_shift = 0

    has_int_digits = false
    while true
      ptr, digit = parse_hex(ptr, finish)
      break unless digit
      has_int_digits = true

      if mantissa != 0
        exp_shift += 4
      elsif digit != 0
        exp_shift = 8 - digit.leading_zeros_count
      end

      mix_digit
    end

    if ptr < finish && ptr.value === '.'
      ptr += 1
      has_frac_digits = false
      while true
        ptr, digit = parse_hex(ptr, finish)
        break unless digit
        has_frac_digits = true

        if mantissa == 0
          exp_shift -= 4
          if digit != 0
            exp_shift += 8 - digit.leading_zeros_count
          end
        end

        mix_digit
      end
    end

    return yield "expected at least one digit" unless has_int_digits || has_frac_digits

    check_ch 'p', 'P'

    ptr, exp_negative = parse_sign(ptr, finish)

    exp_add = 0
    has_exp_digits = false
    while true
      ptr, digit = parse_dec(ptr, finish)
      break unless digit
      has_exp_digits = true

      return yield "exponent overflow" if exp_add > Int32::MAX // 10
      exp_add &*= 10
      return yield "exponent overflow" if exp_add > Int32::MAX &- digit
      exp_add &+= digit
    end

    return yield "empty exponent" unless has_exp_digits
    return yield "trailing characters" unless ptr == finish

    return make_float(negative, 0, 0) if mantissa == 0

    exp_shift += F::MAX_EXP - 2
    if exp_negative
      exp_shift -= exp_add
    else
      exp_shift += exp_add
    end

    if mantissa <= (mantissa_max >> 1)
      mantissa <<= F::MANT_DIGITS - (sizeof(U) * 8 - mantissa.leading_zeros_count) + 1
    end

    if exp_shift <= 0
      trailing_nonzero ||= mantissa & ~(U::MAX << (1 - exp_shift)) != 0
      mantissa >>= 1 - exp_shift
      round_up = (mantissa & 0b1) != 0 && ((mantissa & 0b10) != 0 || trailing_nonzero)
      mantissa >>= 1
      mantissa &+= 1 if round_up
      exp_shift = mantissa > (mantissa_max >> 2) ? 1 : 0
    elsif mantissa > (mantissa_max >> 1)
      round_up = (mantissa & 0b1) != 0 && ((mantissa & 0b10) != 0 || trailing_nonzero)
      mantissa >>= 1
      mantissa &+= 1 if round_up
      exp_shift += 1 if mantissa > (mantissa_max >> 1)
    end

    return make_float(negative, 0, F::MAX_EXP * 2 - 1) if exp_shift >= F::MAX_EXP * 2 - 1

    make_float(negative, mantissa, exp_shift)
  end

  private def self.make_float(negative, mantissa, exponent) : F
    u = negative ? U.new!(1) << (sizeof(U) * 8 - 1) : U.zero
    u |= mantissa & ~(U::MAX << (F::MANT_DIGITS - 1))
    u |= U.new!(exponent) << (F::MANT_DIGITS - 1)

    u.unsafe_as(F)
  end

  private macro check_ch(*ch)
    unless ptr < finish && ptr.value.unsafe_chr.in?({{ ch }})
      return yield "expected {{ ch.map(&.stringify).join(%( or )).id }}"
    end
    ptr += 1
  end

  # `/[+-]?/`
  private def self.parse_sign(ptr, finish)
    if ptr < finish
      case ptr.value
      when '+'
        return {ptr + 1, false}
      when '-'
        return {ptr + 1, true}
      end
    end

    {ptr, false}
  end

  # `/[0-9]?/`
  private def self.parse_dec(ptr, finish)
    if ptr < finish
      case ch = ptr.value
      when 0x30..0x39
        return {ptr + 1, ch &- 0x30}
      end
    end

    {ptr, nil}
  end

  # `/[0-9A-Fa-f]?/`
  private def self.parse_hex(ptr, finish)
    if ptr < finish
      case ch = ptr.value
      when 0x30..0x39
        return {ptr + 1, ch &- 0x30}
      when 0x41..0x46
        return {ptr + 1, ch &- 0x37}
      when 0x61..0x66
        return {ptr + 1, ch &- 0x57}
      end
    end

    {ptr, nil}
  end

  # Precondition: `str.each_char.all?(&.ascii_lowercase?)`
  private def self.eq_case_insensitive?(bytes : Bytes, str : String) : Bool
    return false unless bytes.size == str.bytesize
    ptr = str.to_unsafe

    bytes.each_with_index do |b, i|
      b |= 0x20 if 0x41 <= b <= 0x5A
      return false unless b == ptr[i]
    end

    true
  end

  private macro mix_digit
    if mantissa > (mantissa_max >> 1)
      trailing_nonzero ||= digit != 0
    elsif mantissa > (mantissa_max >> 2)
      # 00000000 000[.... ........ .......]
      mantissa <<= 1
      mantissa |= digit >> 3
      trailing_nonzero ||= digit & 0b0111 != 0
      # 00000000 00[..... ........ ......]? ???
    elsif mantissa > (mantissa_max >> 3)
      # 00000000 0000[... ........ .......]
      mantissa <<= 2
      mantissa |= digit >> 2
      trailing_nonzero ||= digit & 0b0011 != 0
      # 00000000 00[..... ........ .....]?? ??
    elsif mantissa > (mantissa_max >> 4)
      # 00000000 00000[.. ........ .......]
      mantissa <<= 3
      mantissa |= digit >> 1
      trailing_nonzero ||= digit & 0b0001 != 0
      # 00000000 00[..... ........ ....]??? ?
    else
      mantissa <<= 4
      mantissa |= digit
    end
  end

  # sign and special values are handled in `Float::Printer.check_finite_float`
  @[AlwaysInline]
  def self.to_s(io : IO, num : F, *, prefix : Bool = true, upcase : Bool = false, precision : Int? = nil, alternative : Bool = false) : Nil
    u = num.unsafe_as(U)
    exponent = ((u >> (F::MANT_DIGITS - 1)) & (F::MAX_EXP * 2 - 1)).to_i
    mantissa = u & ~(U::MAX << (F::MANT_DIGITS - 1))

    if exponent < 1
      exponent += 1
    else
      mantissa |= U.new!(1) << (F::MANT_DIGITS - 1)
    end

    if precision
      trailing_zeros = {(precision * 4 + 1 - F::MANT_DIGITS) // 4, 0}.max
      precision -= trailing_zeros

      one_bit = mantissa.bits_set?(U.new!(1) << (F::MANT_DIGITS - 4 * precision - 1))
      half_bit = mantissa.bits_set?(U.new!(1) << (F::MANT_DIGITS - 4 * precision - 2))
      trailing_nonzero = (mantissa & ~(U::MAX << (F::MANT_DIGITS - 4 * precision - 2))) != 0
      if half_bit && (one_bit || trailing_nonzero)
        mantissa &+= U.new!(1) << (F::MANT_DIGITS - 4 * precision - 2)
      end
    else
      trailing_zeros = 0
    end

    io << (upcase ? "0X" : "0x") if prefix
    io << (mantissa >> (F::MANT_DIGITS - 1))
    mantissa &= ~(U::MAX << (F::MANT_DIGITS - 1))

    io << '.' if (precision || mantissa) != 0 || alternative

    if precision
      precision.times do
        digit = mantissa >> (F::MANT_DIGITS - 5)
        digit.to_s(io, base: 16, upcase: upcase)
        mantissa <<= 4
        mantissa &= ~(U::MAX << (F::MANT_DIGITS - 1))
      end
    else
      while mantissa != 0
        digit = mantissa >> (F::MANT_DIGITS - 5)
        digit.to_s(io, base: 16, upcase: upcase)
        mantissa <<= 4
        mantissa &= ~(U::MAX << (F::MANT_DIGITS - 1))
      end
    end

    trailing_zeros.times { io << '0' }

    if num == 0
      io << (upcase ? "P+0" : "p+0")
    else
      exponent -= F::MAX_EXP - 1

      io << (upcase ? 'P' : 'p')
      io << (exponent >= 0 ? '+' : '-')
      io << exponent.abs
    end
  end

  def self.to_s_size(num : F, *, precision : Int? = nil, alternative : Bool = false)
    u = num.unsafe_as(U)
    exponent = ((u >> (F::MANT_DIGITS - 1)) & (F::MAX_EXP * 2 - 1)).to_i
    mantissa = u & ~(U::MAX << (F::MANT_DIGITS - 1))

    if exponent < 1
      exponent += 1
    end

    size = 6 # 0x0p+0 (integral part cannot be greater than 2)

    if precision
      size += 1 if precision != 0 || alternative # .
      size += precision
    else
      size += 1 if mantissa != 0 || alternative # .
      while mantissa != 0
        size += 1
        mantissa <<= 4
        mantissa &= ~(U::MAX << (F::MANT_DIGITS - 1))
      end
    end

    if num != 0
      exponent = (exponent - F::MAX_EXP - 1).abs
      while exponent >= 10
        exponent //= 10
        size += 1
      end
    end

    size
  end
end
