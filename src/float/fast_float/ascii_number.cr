require "./float_common"

module Float::FastFloat
  # Next function can be micro-optimized, but compilers are entirely able to
  # optimize it well.
  def self.is_integer?(c : UC) : Bool forall UC
    !(c > '9'.ord || c < '0'.ord)
  end

  # Read 8 UC into a u64. Truncates UC if not char.
  def self.read8_to_u64(chars : UC*) : UInt64 forall UC
    val = uninitialized UInt64
    chars.as(UInt8*).copy_to(pointerof(val).as(UInt8*), sizeof(UInt64))
    {% if IO::ByteFormat::SystemEndian == IO::ByteFormat::BigEndian %}
      val.byte_swap
    {% else %}
      val
    {% end %}
  end

  # credit  @aqrit
  def self.parse_eight_digits_unrolled(val : UInt64) : UInt32
    mask = 0x000000FF000000FF_u64
    mul1 = 0x000F424000000064_u64 # 100 + (1000000ULL << 32)
    mul2 = 0x0000271000000001_u64 # 1 + (10000ULL << 32)
    val &-= 0x3030303030303030
    val = (val &* 10) &+ val.unsafe_shr(8) # val = (val * 2561) >> 8
    val = (((val & mask) &* mul1) &+ ((val.unsafe_shr(16) & mask) &* mul2)).unsafe_shr(32)
    val.to_u32!
  end

  # Call this if chars are definitely 8 digits.
  def self.parse_eight_digits_unrolled(chars : UC*) : UInt32 forall UC
    parse_eight_digits_unrolled(read8_to_u64(chars))
  end

  # credit @aqrit
  def self.is_made_of_eight_digits_fast?(val : UInt64) : Bool
    ((val &+ 0x4646464646464646_u64) | (val &- 0x3030303030303030_u64)) & 0x8080808080808080_u64 == 0
  end

  # NOTE(crystal): returns {p, i}
  def self.loop_parse_if_eight_digits(p : UInt8*, pend : UInt8*, i : UInt64) : {UInt8*, UInt64}
    # optimizes better than parse_if_eight_digits_unrolled() for UC = char.
    while pend - p >= 8 && is_made_of_eight_digits_fast?(read8_to_u64(p))
      i = i &* 100000000 &+ parse_eight_digits_unrolled(read8_to_u64(p)) # in rare cases, this will overflow, but that's ok
      p += 8
    end
    {p, i}
  end

  enum ParseError
    NoError

    # [JSON-only] The minus sign must be followed by an integer.
    MissingIntegerAfterSign

    # A sign must be followed by an integer or dot.
    MissingIntegerOrDotAfterSign

    # [JSON-only] The integer part must not have leading zeros.
    LeadingZerosInIntegerPart

    # [JSON-only] The integer part must have at least one digit.
    NoDigitsInIntegerPart

    # [JSON-only] If there is a decimal point, there must be digits in the
    # fractional part.
    NoDigitsInFractionalPart

    # The mantissa must have at least one digit.
    NoDigitsInMantissa

    # Scientific notation requires an exponential part.
    MissingExponentialPart
  end

  struct ParsedNumberStringT(UC)
    property exponent : Int64 = 0
    property mantissa : UInt64 = 0
    property lastmatch : UC* = Pointer(UC).null
    property negative : Bool = false
    property valid : Bool = false
    property too_many_digits : Bool = false
    # contains the range of the significant digits
    property integer : Slice(UC) = Slice(UC).empty  # non-nullable
    property fraction : Slice(UC) = Slice(UC).empty # nullable
    property error : ParseError = :no_error
  end

  alias ByteSpan = ::Bytes
  alias ParsedNumberString = ParsedNumberStringT(UInt8)

  def self.report_parse_error(p : UC*, error : ParseError) : ParsedNumberStringT(UC) forall UC
    answer = ParsedNumberStringT(UC).new
    answer.valid = false
    answer.lastmatch = p
    answer.error = error
    answer
  end

  # Assuming that you use no more than 19 digits, this will parse an ASCII
  # string.
  def self.parse_number_string(p : UC*, pend : UC*, options : ParseOptionsT(UC)) : ParsedNumberStringT(UC) forall UC
    fmt = options.format
    decimal_point = options.decimal_point

    answer = ParsedNumberStringT(UInt8).new
    answer.valid = false
    answer.too_many_digits = false
    answer.negative = p.value === '-'

    if p.value === '-' || (!fmt.json_fmt? && p.value === '+')
      p += 1
      if p == pend
        return report_parse_error(p, :missing_integer_or_dot_after_sign)
      end
      if fmt.json_fmt?
        if !is_integer?(p.value) # a sign must be followed by an integer
          return report_parse_error(p, :missing_integer_after_sign)
        end
      else
        if !is_integer?(p.value) && p.value != decimal_point # a sign must be followed by an integer or the dot
          return report_parse_error(p, :missing_integer_or_dot_after_sign)
        end
      end
    end
    start_digits = p

    i = 0_u64 # an unsigned int avoids signed overflows (which are bad)

    while p != pend && is_integer?(p.value)
      # a multiplication by 10 is cheaper than an arbitrary integer multiplication
      i = i &* 10 &+ (p.value &- '0'.ord).to_u64! # might overflow, we will handle the overflow later
      p += 1
    end
    end_of_integer_part = p
    digit_count = (end_of_integer_part - start_digits).to_i32!
    answer.integer = Slice.new(start_digits, digit_count)
    if fmt.json_fmt?
      # at least 1 digit in integer part, without leading zeros
      if digit_count == 0
        return report_parse_error(p, :no_digits_in_integer_part)
      end
      if start_digits[0] === '0' && digit_count > 1
        return report_parse_error(p, :leading_zeros_in_integer_part)
      end
    end

    exponent = 0_i64
    has_decimal_point = p != pend && p.value == decimal_point
    if has_decimal_point
      p += 1
      before = p
      # can occur at most twice without overflowing, but let it occur more, since
      # for integers with many digits, digit parsing is the primary bottleneck.
      p, i = loop_parse_if_eight_digits(p, pend, i)

      while p != pend && is_integer?(p.value)
        digit = (p.value &- '0'.ord).to_u8!
        p += 1
        i = i &* 10 &+ digit # in rare cases, this will overflow, but that's ok
      end
      exponent = before - p
      answer.fraction = Slice.new(before, (p - before).to_i32!)
      digit_count &-= exponent
    end
    if fmt.json_fmt?
      # at least 1 digit in fractional part
      if has_decimal_point && exponent == 0
        return report_parse_error(p, :no_digits_in_fractional_part)
      end
    elsif digit_count == 0 # we must have encountered at least one integer!
      return report_parse_error(p, :no_digits_in_mantissa)
    end
    exp_number = 0_i64 # explicit exponential part
    if (fmt.scientific? && p != pend && p.value.unsafe_chr.in?('e', 'E')) ||
       (fmt.fortran_fmt? && p != pend && p.value.unsafe_chr.in?('+', '-', 'd', 'D'))
      location_of_e = p
      if p.value.unsafe_chr.in?('e', 'E', 'd', 'D')
        p += 1
      end
      neg_exp = false
      if p != pend && p.value === '-'
        neg_exp = true
        p += 1
      elsif p != pend && p.value === '+' # '+' on exponent is allowed by C++17 20.19.3.(7.1)
        p += 1
      end
      if p == pend || !is_integer?(p.value)
        if !fmt.fixed?
          # The exponential part is invalid for scientific notation, so it must
          # be a trailing token for fixed notation. However, fixed notation is
          # disabled, so report a scientific notation error.
          return report_parse_error(p, :missing_exponential_part)
        end
        # Otherwise, we will be ignoring the 'e'.
        p = location_of_e
      else
        while p != pend && is_integer?(p.value)
          digit = (p.value &- '0'.ord).to_u8!
          if exp_number < 0x10000000
            exp_number = exp_number &* 10 &+ digit
          end
          p += 1
        end
        if neg_exp
          exp_number = 0_i64 &- exp_number
        end
        exponent &+= exp_number
      end
    else
      # If it scientific and not fixed, we have to bail out.
      if fmt.scientific? && !fmt.fixed?
        return report_parse_error(p, :missing_exponential_part)
      end
    end
    answer.lastmatch = p
    answer.valid = true

    # If we frequently had to deal with long strings of digits,
    # we could extend our code by using a 128-bit integer instead
    # of a 64-bit integer. However, this is uncommon.
    #
    # We can deal with up to 19 digits.
    if digit_count > 19 # this is uncommon
      # It is possible that the integer had an overflow.
      # We have to handle the case where we have 0.0000somenumber.
      # We need to be mindful of the case where we only have zeroes...
      # E.g., 0.000000000...000.
      start = start_digits
      while start != pend && (start.value === '0' || start.value == decimal_point)
        if start.value === '0'
          digit_count &-= 1
        end
        start += 1
      end

      if digit_count > 19
        answer.too_many_digits = true
        # Let us start again, this time, avoiding overflows.
        # We don't need to check if is_integer, since we use the
        # pre-tokenized spans from above.
        i = 0_u64
        p = answer.integer.to_unsafe
        int_end = p + answer.integer.size
        minimal_nineteen_digit_integer = 1000000000000000000_u64
        while i < minimal_nineteen_digit_integer && p != int_end
          i = i &* 10 &+ (p.value &- '0'.ord).to_u64!
          p += 1
        end
        if i >= minimal_nineteen_digit_integer # We have a big integers
          exponent = (end_of_integer_part - p) &+ exp_number
        else # We have a value with a fractional component.
          p = answer.fraction.to_unsafe
          frac_end = p + answer.fraction.size
          while i < minimal_nineteen_digit_integer && p != frac_end
            i = i &* 10 &+ (p.value &- '0'.ord).to_u64!
            p += 1
          end
          exponent = (answer.fraction.to_unsafe - p) &+ exp_number
        end
        # We have now corrected both exponent and i, to a truncated value
      end
    end
    answer.exponent = exponent
    answer.mantissa = i
    answer
  end
end
