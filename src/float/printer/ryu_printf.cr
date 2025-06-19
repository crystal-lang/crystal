{% skip_file unless String::Formatter::HAS_RYU_PRINTF %}

require "./ryu_printf_table"

# Source port of Ryu Printf's reference implementation in C.
#
# The following is their license:
#
#   Copyright 2018 Ulf Adams
#
#   The contents of this file may be used under the terms of the Apache License,
#   Version 2.0.
#
#      (See accompanying file LICENSE-Apache or copy at
#       http://www.apache.org/licenses/LICENSE-2.0)
#
#   Alternatively, the contents of this file may be used under the terms of
#   the Boost Software License, Version 1.0.
#      (See accompanying file LICENSE-Boost or copy at
#       https://www.boost.org/LICENSE_1_0.txt)
#
#   Unless required by applicable law or agreed to in writing, this software
#   is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#   KIND, either express or implied.
module Float::Printer::RyuPrintf
  # Current revision: https://github.com/ulfjack/ryu/tree/75d5a85440ed356ad7b23e9e6002d71f62a6255c

  # Returns the number of decimal digits in v, which must not contain more than 9 digits.
  private def self.decimal_length9(v : UInt32) : UInt32
    # Function precondition: v is not a 10-digit number.
    # (f2s: 9 digits are sufficient for round-tripping.)
    # (d2fixed: We print 9-digit blocks.)
    case v
    when .>=(100000000) then 9_u32
    when .>=(10000000)  then 8_u32
    when .>=(1000000)   then 7_u32
    when .>=(100000)    then 6_u32
    when .>=(10000)     then 5_u32
    when .>=(1000)      then 4_u32
    when .>=(100)       then 3_u32
    when .>=(10)        then 2_u32
    else
      1_u32
    end
  end

  private def self.log10_pow2(e : Int32) : UInt32
    # The first value this approximation fails for is 2^1651 which is just greater than 10^297.
    (e.to_u32! &* 78913) >> 18
  end

  M_INV_5 = 14757395258967641293u64 # 5 * m_inv_5 = 1 (mod 2^64)
  N_DIV_5 =  3689348814741910323u64 # #{ n | n = 0 (mod 2^64) } = 2^64 / 5

  private def self.pow5_factor(value : UInt64) : UInt32
    count = 0_u32
    while true
      value &*= M_INV_5
      break if value > N_DIV_5
      count &+= 1
    end
    count
  end

  # Returns true if value is divisible by 5^p.
  private def self.multiple_of_power_of_5?(value : UInt64, p : UInt32)
    pow5_factor(value) >= p
  end

  # Returns true if value is divisible by 2^p.
  private def self.multiple_of_power_of_2?(value : UInt64, p : UInt32)
    value & ~(UInt64::MAX << p) == 0
  end

  private def self.umul128(a : UInt64, b : UInt64) : {UInt64, UInt64}
    a_lo = a.to_u32!.to_u64!
    a_hi = (a >> 32).to_u32!.to_u64!
    b_lo = b.to_u32!
    b_hi = (b >> 32).to_u32!

    b00 = a_lo &* b_lo
    b01 = a_lo &* b_hi
    b10 = a_hi &* b_lo
    b11 = a_hi &* b_hi

    b00_lo = b00.to_u32!
    b00_hi = (b00 >> 32).to_u32!

    mid1 = b10 &+ b00_hi
    mid1_lo = mid1.to_u32!
    mid1_hi = (mid1 >> 32).to_u32!

    mid2 = b01 &+ mid1_lo
    mid2_lo = mid2.to_u32!
    mid2_hi = (mid2 >> 32).to_u32!

    {b11 &+ mid1_hi &+ mid2_hi, (mid2_lo.to_u64! << 32) | b00_lo}
  end

  private def self.shiftright128(lo : UInt64, hi : UInt64, dist : UInt32) : UInt64
    # We don't need to handle the case dist >= 64 here
    (hi << (64 &- dist)) | (lo >> dist)
  end

  # Returns the low 64 bits of the high 128 bits of the 256-bit product of a and b.
  private def self.umul256_hi128_lo64(a_hi : UInt64, a_lo : UInt64, b_hi : UInt64, b_lo : UInt64)
    b00_hi, _ = umul128(a_lo, b_lo)
    b01_hi, b01_lo = umul128(a_lo, b_hi)
    b10_hi, b10_lo = umul128(a_hi, b_lo)
    _, b11_lo = umul128(a_hi, b_hi)

    temp1_lo = b10_lo &+ b00_hi
    temp1_hi = b10_hi &+ (temp1_lo < b10_lo ? 1 : 0)
    temp2_lo = b01_lo &+ temp1_lo
    temp2_hi = b01_hi &+ (temp2_lo < b01_lo ? 1 : 0)
    b11_lo &+ temp1_hi &+ temp2_hi
  end

  private def self.uint128_mod1e9(v_hi : UInt64, v_lo : UInt64) : UInt32
    # After multiplying, we're going to shift right by 29, then truncate to uint32_t.
    # This means that we need only 29 + 32 = 61 bits, so we can truncate to uint64_t before shifting.
    multiplied = umul256_hi128_lo64(v_hi, v_lo, 0x89705F4136B4A597u64, 0x31680A88F8953031u64)

    # For uint32_t truncation, see the mod1e9() comment in d2s_intrinsics.h.
    shifted = (multiplied >> 29).to_u32!

    v_lo.to_u32! &- 1000000000_u32 &* shifted
  end

  private def self.mulshift_mod1e9(m : UInt64, mul : {UInt64, UInt64, UInt64}, j : Int32) : UInt32
    high0, low0 = umul128(m, mul[0])
    high1, low1 = umul128(m, mul[1])
    high2, low2 = umul128(m, mul[2])

    s0high = low1 &+ high0 # 64
    c1 = s0high < low1 ? 1 : 0
    s1low = low2 &+ high1 &+ c1 # 128
    c2 = s1low < low2 ? 1 : 0   # high1 + c1 can't overflow, so compare against low2
    s1high = high2 &+ c2        # 192
    dist = (j &- 128).to_u32!   # dist: [0, 52]
    shiftedhigh = s1high >> dist
    shiftedlow = shiftright128(s1low, s1high, dist)
    uint128_mod1e9(shiftedhigh, shiftedlow)
  end

  private def self.index_for_exponent(e : UInt32)
    (e &+ 15) // 16
  end

  private ADDITIONAL_BITS_2 = 120

  private def self.pow10_bits_for_index(idx : UInt32)
    idx &* 16 &+ ADDITIONAL_BITS_2
  end

  private def self.length_for_index(idx : UInt32)
    # +1 for ceil, +16 for mantissa, +8 to round up when dividing by 9
    (log10_pow2(16 &* idx.to_i32!) &+ 25) // 9
  end

  # Convert `digits` to a sequence of decimal digits. Append the digits to the result.
  # The caller has to guarantee that:
  #   10^(olength-1) <= digits < 10^olength
  # e.g., by passing `olength` as `decimalLength9(digits)`.
  private def self.append_n_digits(olength : UInt32, digits : UInt32, result : UInt8*)
    i = 0_u32
    while digits >= 10000
      c = digits &- 10000 &* (digits // 10000)
      digits //= 10000
      c0 = (c % 100) << 1
      c1 = (c // 100) << 1
      (DIGIT_TABLE + c0).copy_to(result + olength - i - 2, 2)
      (DIGIT_TABLE + c1).copy_to(result + olength - i - 4, 2)
      i &+= 4
    end
    if digits >= 100
      c = (digits % 100) << 1
      digits //= 100
      (DIGIT_TABLE + c).copy_to(result + olength - i - 2, 2)
      i &+= 2
    end
    if digits >= 10
      c = digits << 1
      (DIGIT_TABLE + c).copy_to(result + olength - i - 2, 2)
    else
      result.value = '0'.ord.to_u8! &+ digits
    end
  end

  # Convert `digits` to a sequence of decimal digits. Print the first digit, followed by a decimal
  # dot '.' followed by the remaining digits. The caller has to guarantee that:
  #   10^(olength-1) <= digits < 10^olength
  # e.g., by passing `olength` as `decimalLength9(digits)`.
  private def self.append_d_digits(olength : UInt32, digits : UInt32, result : UInt8*)
    i = 0_u32
    while digits >= 10000
      c = digits &- 10000 &* (digits // 10000)
      digits //= 10000
      c0 = (c % 100) << 1
      c1 = (c // 100) << 1
      (DIGIT_TABLE + c0).copy_to(result + olength + 1 - i - 2, 2)
      (DIGIT_TABLE + c1).copy_to(result + olength + 1 - i - 4, 2)
      i &+= 4
    end
    if digits >= 100
      c = (digits % 100) << 1
      digits //= 100
      (DIGIT_TABLE + c).copy_to(result + olength + 1 - i - 2, 2)
      i &+= 2
    end
    if digits >= 10
      c = digits << 1
      result[2] = DIGIT_TABLE[c &+ 1]
      result[1] = '.'.ord.to_u8!
      result[0] = DIGIT_TABLE[c]
    else
      result[1] = '.'.ord.to_u8!
      result[0] = '0'.ord.to_u8! &+ digits
    end
  end

  # Convert `digits` to decimal and write the last `count` decimal digits to result.
  # If `digits` contains additional digits, then those are silently ignored.
  private def self.append_c_digits(count : UInt32, digits : UInt32, result : UInt8*)
    i = 0_u32

    # Copy pairs of digits from DIGIT_TABLE.
    while i < count &- 1
      c = (digits % 100) << 1
      digits //= 100
      (DIGIT_TABLE + c).copy_to(result + count - i - 2, 2)
      i &+= 2
    end

    # Generate the last digit if count is odd.
    if i < count
      c = '0'.ord.to_u8! &+ (digits % 10)
      result[count - i - 1] = c
    end
  end

  # Convert `digits` to decimal and write the last 9 decimal digits to result.
  # If `digits` contains additional digits, then those are silently ignored.
  private def self.append_nine_digits(digits : UInt32, result : UInt8*)
    if digits == 0
      Slice.new(result, 9).fill('0'.ord.to_u8!)
      return
    end

    c = digits &- 10000 &* (digits // 10000)
    digits //= 10000
    c0 = (c % 100) << 1
    c1 = (c // 100) << 1
    (DIGIT_TABLE + c0).copy_to(result + 7, 2)
    (DIGIT_TABLE + c1).copy_to(result + 5, 2)

    c = digits &- 10000 &* (digits // 10000)
    digits //= 10000
    c0 = (c % 100) << 1
    c1 = (c // 100) << 1
    (DIGIT_TABLE + c0).copy_to(result + 3, 2)
    (DIGIT_TABLE + c1).copy_to(result + 1, 2)

    result.value = '0'.ord.to_u8! &+ digits
  end

  MANTISSA_BITS = Float64::MANT_DIGITS - 1
  EXPONENT_BITS = 11

  # NOTE: in Crystal *d* must be positive and finite
  private def self.extract_float(d : Float64)
    bits = d.unsafe_as(UInt64)

    ieee_mantissa = bits & ~(UInt64::MAX << MANTISSA_BITS)
    ieee_exponent = (bits >> MANTISSA_BITS) & ~(UInt64::MAX << EXPONENT_BITS)

    if ieee_exponent == 0
      e2 = 1 &- 1023 &- MANTISSA_BITS
      m2 = ieee_mantissa
    else
      e2 = ieee_exponent.to_i32! &- 1023 &- MANTISSA_BITS
      m2 = (1_u64 << MANTISSA_BITS) | ieee_mantissa
    end

    {e2, m2}
  end

  def self.d2fixed_buffered_n(d : Float64, precision : UInt32, result : UInt8*)
    e2, m2 = extract_float(d)
    index = 0
    nonzero = false

    if e2 >= -MANTISSA_BITS
      idx = e2 < 0 ? 0_u32 : index_for_exponent(e2.to_u32!)
      p10bits = pow10_bits_for_index(idx)
      len = length_for_index(idx).to_i32!

      (len - 1).downto(0) do |i|
        j = p10bits &- e2
        # Temporary: j is usually around 128, and by shifting a bit, we push it to 128 or above, which is
        # a slightly faster code path in mulshift_mod1e9. Instead, we can just increase the multipliers.
        digits = mulshift_mod1e9(m2 << 8, POW10_SPLIT[POW10_OFFSET[idx] &+ i], (j &+ 8).to_i32!)
        if nonzero
          append_nine_digits(digits, result + index)
          index &+= 9
        elsif digits != 0
          olength = decimal_length9(digits)
          append_n_digits(olength, digits, result + index)
          index &+= olength
          nonzero = true
        end
      end
    end

    unless nonzero
      result[index] = '0'.ord.to_u8!
      index &+= 1
    end

    if precision > 0
      result[index] = '.'.ord.to_u8!
      index &+= 1
    end

    if e2 >= 0
      Slice.new(result + index, precision).fill('0'.ord.to_u8!)
      index &+= precision
      return index
    end

    idx = (0 &- e2) // 16
    blocks = precision // 9 &+ 1
    # 0 = don't round up; 1 = round up unconditionally; 2 = round up if odd.
    round_up = 0
    i = 0_u32

    if blocks <= MIN_BLOCK_2[idx]
      i = blocks
      Slice.new(result + index, precision).fill('0'.ord.to_u8!)
      index &+= precision
    elsif i < MIN_BLOCK_2[idx]
      i = MIN_BLOCK_2[idx].to_u32!
      Slice.new(result + index, i &* 9).fill('0'.ord.to_u8!)
      index &+= i &* 9
    end

    while i < blocks
      j = ADDITIONAL_BITS_2 &- e2 &- 16 &* idx
      p = POW10_OFFSET_2[idx] &+ i &- MIN_BLOCK_2[idx]

      if p >= POW10_OFFSET_2[idx + 1]
        # If the remaining digits are all 0, then we might as well use memset.
        # No rounding required in this case.
        fill = precision &- 9 &* i
        Slice.new(result + index, fill).fill('0'.ord.to_u8!)
        index &+= fill
        break
      end

      # Temporary: j is usually around 128, and by shifting a bit, we push it to 128 or above, which is
      # a slightly faster code path in mulShift_mod1e9. Instead, we can just increase the multipliers.
      digits = mulshift_mod1e9(m2 << 8, POW10_SPLIT_2[p], j &+ 8)
      if i < blocks &- 1
        append_nine_digits(digits, result + index)
        index &+= 9
      else
        maximum = precision &- 9 &* i
        last_digit = 0_u32
        (9 &- maximum).times do
          last_digit = digits % 10
          digits //= 10
        end

        if last_digit != 5
          round_up = last_digit > 5 ? 1 : 0
        else
          # Is m * 10^(additionalDigits + 1) / 2^(-e2) integer?
          required_twos = 0 &- e2 &- precision.to_i32! &- 1
          trailing_zeros = required_twos <= 0 || (required_twos < 60 && multiple_of_power_of_2?(m2, required_twos.to_u32!))
          round_up = trailing_zeros ? 2 : 1
        end

        if maximum > 0
          append_c_digits(maximum, digits, result + index)
          index &+= maximum
        end
        break
      end

      i &+= 1
    end

    if round_up != 0
      round_index = index
      dot_index = 0
      while true
        round_index &-= 1
        c = result[round_index]
        if round_index == -1 || c === '-'
          result[round_index &+ 1] = '1'.ord.to_u8!
          if dot_index > 0
            result[dot_index] = '0'.ord.to_u8!
            result[dot_index &+ 1] = '.'.ord.to_u8!
          end
          result[index] = '0'.ord.to_u8!
          index &+= 1
          break
        end

        if c === '.'
          dot_index = round_index
          next
        elsif c === '9'
          result[round_index] = '0'.ord.to_u8!
          round_up = 1
          next
        else
          result[round_index] = c &+ 1 unless round_up == 2 && c % 2 == 0
          break
        end
      end
    end

    index
  end

  def self.d2exp_buffered_n(d : Float64, precision : UInt32, result : UInt8*)
    if d == 0
      result[0] = '0'.ord.to_u8!
      index = 1
      if precision > 0
        result[index] = '.'.ord.to_u8!
        index &+= 1
        Slice.new(result + index, precision).fill('0'.ord.to_u8!)
        index &+= precision
      end
      result[index] = 'e'.ord.to_u8!
      result[index + 1] = '+'.ord.to_u8!
      result[index + 2] = '0'.ord.to_u8!
      return index &+ 3
    end

    e2, m2 = extract_float(d)
    print_decimal_digit = precision > 0
    precision &+= 1
    index = 0
    digits = 0_u32
    printed_digits = 0_u32
    available_digits = 0_u32
    exp = 0

    if e2 >= -MANTISSA_BITS
      idx = e2 < 0 ? 0_u32 : index_for_exponent(e2.to_u32!)
      p10bits = pow10_bits_for_index(idx)
      len = length_for_index(idx).to_i32!

      (len - 1).downto(0) do |i|
        j = p10bits &- e2
        # Temporary: j is usually around 128, and by shifting a bit, we push it to 128 or above, which is
        # a slightly faster code path in mulshift_mod1e9. Instead, we can just increase the multipliers.
        digits = mulshift_mod1e9(m2 << 8, POW10_SPLIT[POW10_OFFSET[idx] &+ i], (j &+ 8).to_i32!)
        if printed_digits != 0
          if printed_digits &+ 9 > precision
            available_digits = 9_u32
            break
          end
          append_nine_digits(digits, result + index)
          index &+= 9
          printed_digits &+= 9
        elsif digits != 0
          available_digits = decimal_length9(digits)
          exp = i &* 9 &+ available_digits.to_i32! &- 1
          break if available_digits > precision
          if print_decimal_digit
            append_d_digits(available_digits, digits, result + index)
            index &+= available_digits &+ 1 # +1 for decimal point
          else
            result[index] = '0'.ord.to_u8! &+ digits
            index &+= 1
          end
          printed_digits = available_digits
          available_digits = 0_u32
        end
      end
    end

    if e2 < 0 && available_digits == 0
      idx = (0 &- e2) // 16
      (MIN_BLOCK_2[idx]..200).each do |i|
        j = ADDITIONAL_BITS_2 &- e2 &- 16 &* idx
        p = POW10_OFFSET_2[idx] &+ i &- MIN_BLOCK_2[idx]
        # Temporary: j is usually around 128, and by shifting a bit, we push it to 128 or above, which is
        # a slightly faster code path in mulShift_mod1e9. Instead, we can just increase the multipliers.
        digits = p >= POW10_OFFSET_2[idx &+ 1] ? 0_u32 : mulshift_mod1e9(m2 << 8, POW10_SPLIT_2[p], j &+ 8)

        if printed_digits != 0
          if printed_digits &+ 9 > precision
            available_digits = 9_u32
            break
          end
          append_nine_digits(digits, result + index)
          index &+= 9
          printed_digits &+= 9
        elsif digits != 0
          available_digits = decimal_length9(digits)
          exp = (-1 &- i) &* 9 &+ available_digits.to_i32! &- 1
          break if available_digits > precision
          if print_decimal_digit
            append_d_digits(available_digits, digits, result + index)
            index &+= available_digits &+ 1 # +1 for decimal point
          else
            result[index] = '0'.ord.to_u8! &+ digits
            index &+= 1
          end
          printed_digits = available_digits
          available_digits = 0_u32
        end
      end
    end

    maximum = precision &- printed_digits
    digits = 0_u32 if available_digits == 0
    last_digit = 0_u32
    if available_digits > maximum
      (available_digits &- maximum).times do
        last_digit = digits % 10
        digits //= 10
      end
    end

    # 0 = don't round up; 1 = round up unconditionally; 2 = round up if odd.
    round_up = 0
    if last_digit != 5
      round_up = last_digit > 5 ? 1 : 0
    else
      # Is m * 2^e2 * 10^(precision + 1 - exp) integer?
      # precision was already increased by 1, so we don't need to write + 1 here.
      rexp = precision.to_i32! &- exp
      required_twos = 0 &- e2 &- rexp
      trailing_zeros = required_twos <= 0 || (required_twos < 60 && multiple_of_power_of_2?(m2, required_twos.to_u32!))
      if rexp < 0
        required_fives = 0 &- rexp
        trailing_zeros = trailing_zeros && multiple_of_power_of_5?(m2, required_fives.to_u32!)
      end
      round_up = trailing_zeros ? 2 : 1
    end

    if printed_digits != 0
      if digits == 0
        Slice.new(result + index, maximum).fill('0'.ord.to_u8!)
      else
        append_c_digits(maximum, digits, result + index)
      end
      index &+= maximum
    else
      if print_decimal_digit
        append_d_digits(maximum, digits, result + index)
        index &+= maximum &+ 1 # +1 for decimal point
      else
        result[index] = '0'.ord.to_u8! &+ digits
        index &+= 1
      end
    end

    if round_up != 0
      round_index = index
      while true
        round_index &-= 1
        c = result[round_index]
        if round_index == -1 || c === '-'
          result[round_index &+ 1] = '1'.ord.to_u8!
          exp &+= 1
          break
        end

        if c === '.'
          next
        elsif c === '9'
          result[round_index] = '0'.ord.to_u8!
          round_up = 1
          next
        else
          result[round_index] = c &+ 1 unless round_up == 2 && c % 2 == 0
          break
        end
      end
    end

    result[index] = 'e'.ord.to_u8!
    index &+= 1
    if exp < 0
      result[index] = '-'.ord.to_u8!
      exp = 0 &- exp
    else
      result[index] = '+'.ord.to_u8!
    end
    index &+= 1

    if exp >= 100
      c = exp % 10
      (DIGIT_TABLE + ((exp // 10) << 1)).copy_to(result + index, 2)
      result[index &+ 2] = '0'.ord.to_u8! &+ c
      index &+= 3
    elsif exp >= 10
      (DIGIT_TABLE + (exp << 1)).copy_to(result + index, 2)
      index &+= 2
    else
      result[index] = '0'.ord.to_u8! &+ exp
      index &+= 1
    end

    index
  end

  private MAX_FIXED_PRECISION =  66_u32
  private MAX_SCI_PRECISION   = 766_u32

  # Source port of Microsoft STL's `std::to_chars` based on:
  #
  # * https://github.com/ulfjack/ryu/pull/185/files
  # * https://github.com/microsoft/STL/blob/a8888806c6960f1687590ffd4244794c753aa819/stl/inc/charconv#L2324
  # * https://github.com/llvm/llvm-project/blob/701f64790520790f75b1f948a752472d421ddaa3/libcxx/src/include/to_chars_floating_point.h#L836
  def self.d2gen_buffered_n(d : Float64, precision : UInt32, result : UInt8*, alternative : Bool = false)
    if d == 0
      result[0] = '0'.ord.to_u8!
      return {1, 0}
    end

    precision = precision.clamp(1_u32, 1000000_u32)
    if precision <= MAX_SPECIAL_P
      table_begin = SPECIAL_X.to_unsafe + (precision &- 1) * (precision &+ 10) // 2
      table_length = precision.to_i32! &+ 5
    else
      table_begin = ORDINARY_X.to_unsafe
      table_length = {precision, MAX_ORDINARY_P}.min.to_i32! &+ 5
    end

    bits = d.unsafe_as(UInt64)
    index = 0
    while index < table_length
      break if bits <= table_begin[index]
      index &+= 1
    end

    sci_exp_x = index &- 5
    use_fixed_notation = precision > sci_exp_x && sci_exp_x >= -4

    significand_last = exponent_first = exponent_last = Pointer(UInt8).null

    # Write into the local buffer.
    if use_fixed_notation
      effective_precision = precision &- 1 &- sci_exp_x
      max_precision = MAX_FIXED_PRECISION
      len = d2fixed_buffered_n(d, {effective_precision, max_precision}.min, result)
      significand_last = result + len
    else
      effective_precision = precision &- 1
      max_precision = MAX_SCI_PRECISION
      len = d2exp_buffered_n(d, {effective_precision, max_precision}.min, result)
      exponent_first = result + Slice.new(result, len).fast_index('e'.ord.to_u8!, 0).not_nil!
      significand_last = exponent_first
      exponent_last = result + len
    end

    # If we printed a decimal point followed by digits, perform zero-trimming.
    if effective_precision > 0 && !alternative
      while significand_last[-1] === '0' # will stop at '.' or a nonzero digit
        significand_last -= 1
      end

      if significand_last[-1] === '.'
        significand_last -= 1
      end
    end

    # Copy the exponent to the output range.
    unless use_fixed_notation
      exponent_first.move_to(significand_last, exponent_last - exponent_first)
    end

    extra_zeros = effective_precision > max_precision ? effective_precision &- max_precision : 0_u32
    {(significand_last - result + (exponent_last - exponent_first)).to_i32!, extra_zeros.to_i32!}
  end

  def self.d2fixed(d : Float64, precision : Int)
    String.new(2000) do |buffer|
      len = d2fixed_buffered_n(d, precision.to_u32, buffer)
      {len, len}
    end
  end

  def self.d2exp(d : Float64, precision : Int)
    String.new(2000) do |buffer|
      len = d2exp_buffered_n(d, precision.to_u32, buffer)
      {len, len}
    end
  end

  def self.d2gen(d : Float64, precision : Int)
    String.new(773) do |buffer|
      len, _ = d2gen_buffered_n(d, precision.to_u32, buffer)
      {len, len}
    end
  end
end
