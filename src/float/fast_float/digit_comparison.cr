require "./float_common"
require "./bigint"
require "./ascii_number"

module Float::FastFloat
  # 1e0 to 1e19
  POWERS_OF_TEN_UINT64 = [
    1_u64,
    10_u64,
    100_u64,
    1000_u64,
    10000_u64,
    100000_u64,
    1000000_u64,
    10000000_u64,
    100000000_u64,
    1000000000_u64,
    10000000000_u64,
    100000000000_u64,
    1000000000000_u64,
    10000000000000_u64,
    100000000000000_u64,
    1000000000000000_u64,
    10000000000000000_u64,
    100000000000000000_u64,
    1000000000000000000_u64,
    10000000000000000000_u64,
  ]

  # calculate the exponent, in scientific notation, of the number.
  # this algorithm is not even close to optimized, but it has no practical
  # effect on performance: in order to have a faster algorithm, we'd need
  # to slow down performance for faster algorithms, and this is still fast.
  def self.scientific_exponent(num : ParsedNumberStringT(UC)) : Int32 forall UC
    mantissa = num.mantissa
    exponent = num.exponent.to_i32!
    while mantissa >= 10000
      mantissa = mantissa.unsafe_div(10000)
      exponent &+= 4
    end
    while mantissa >= 100
      mantissa = mantissa.unsafe_div(100)
      exponent &+= 2
    end
    while mantissa >= 10
      mantissa = mantissa.unsafe_div(10)
      exponent &+= 1
    end
    exponent
  end

  module BinaryFormat(T, EquivUint)
    # this converts a native floating-point number to an extended-precision float.
    def to_extended(value : T) : AdjustedMantissa
      exponent_mask = self.exponent_mask
      mantissa_mask = self.mantissa_mask
      hidden_bit_mask = self.hidden_bit_mask

      bias = mantissa_explicit_bits &- minimum_exponent
      bits = value.unsafe_as(EquivUint)
      if bits & exponent_mask == 0
        # denormal
        power2 = 1 &- bias
        mantissa = bits & mantissa_mask
      else
        # normal
        power2 = (bits & exponent_mask).unsafe_shr(mantissa_explicit_bits).to_i32!
        power2 &-= bias
        mantissa = (bits & mantissa_mask) | hidden_bit_mask
      end

      AdjustedMantissa.new(power2: power2, mantissa: mantissa.to_u64!)
    end

    # get the extended precision value of the halfway point between b and b+u.
    # we are given a native float that represents b, so we need to adjust it
    # halfway between b and b+u.
    def to_extended_halfway(value : T) : AdjustedMantissa
      am = to_extended(value)
      am.mantissa = am.mantissa.unsafe_shl(1)
      am.mantissa &+= 1
      am.power2 &-= 1
      am
    end

    # round an extended-precision float to the nearest machine float.
    # NOTE(crystal): passes *am* in and out by value
    def round(am : AdjustedMantissa, & : AdjustedMantissa, Int32 -> AdjustedMantissa) : AdjustedMantissa
      mantissa_shift = 64 &- mantissa_explicit_bits &- 1
      if 0 &- am.power2 >= mantissa_shift
        # have a denormal float
        shift = 1 &- am.power2
        am = yield am, {shift, 64}.min
        # check for round-up: if rounding-nearest carried us to the hidden bit.
        am.power2 = am.mantissa < 1_u64.unsafe_shl(mantissa_explicit_bits) ? 0 : 1
        return am
      end

      # have a normal float, use the default shift.
      am = yield am, mantissa_shift

      # check for carry
      if am.mantissa >= 2_u64.unsafe_shl(mantissa_explicit_bits)
        am.mantissa = 1_u64.unsafe_shl(mantissa_explicit_bits)
        am.power2 &+= 1
      end

      # check for infinite: we could have carried to an infinite power
      am.mantissa &= ~(1_u64.unsafe_shl(mantissa_explicit_bits))
      if am.power2 >= infinite_power
        am.power2 = infinite_power
        am.mantissa = 0
      end

      am
    end

    # NOTE(crystal): passes *am* in and out by value
    def round_nearest_tie_even(am : AdjustedMantissa, shift : Int32, & : Bool, Bool, Bool -> Bool) : AdjustedMantissa
      mask = shift == 64 ? UInt64::MAX : 1_u64.unsafe_shl(shift) &- 1
      halfway = shift == 0 ? 0_u64 : 1_u64.unsafe_shl(shift &- 1)
      truncated_bits = am.mantissa & mask
      is_above = truncated_bits > halfway
      is_halfway = truncated_bits == halfway

      # shift digits into position
      if shift == 64
        am.mantissa = 0
      else
        am.mantissa = am.mantissa.unsafe_shr(shift)
      end
      am.power2 &+= shift

      is_odd = am.mantissa.bits_set?(1)
      am.mantissa &+= (yield is_odd, is_halfway, is_above) ? 1 : 0
      am
    end

    # NOTE(crystal): passes *am* in and out by value
    def round_down(am : AdjustedMantissa, shift : Int32) : AdjustedMantissa
      if shift == 64
        am.mantissa = 0
      else
        am.mantissa = am.mantissa.unsafe_shr(shift)
      end
      am.power2 &+= shift
      am
    end

    # NOTE(crystal): returns the new *first* by value
    def skip_zeros(first : UC*, last : UC*) : UC* forall UC
      int_cmp_len = FastFloat.int_cmp_len(UC)
      int_cmp_zeros = FastFloat.int_cmp_zeros(UC)

      val = uninitialized UInt64
      while last - first >= int_cmp_len
        first.copy_to(pointerof(val).as(UC*), int_cmp_len)
        if val != int_cmp_zeros
          break
        end
        first += int_cmp_len
      end
      while first != last
        unless first.value === '0'
          break
        end
        first += 1
      end
      first
    end

    # determine if any non-zero digits were truncated.
    # all characters must be valid digits.
    def is_truncated?(first : UC*, last : UC*) : Bool forall UC
      int_cmp_len = FastFloat.int_cmp_len(UC)
      int_cmp_zeros = FastFloat.int_cmp_zeros(UC)

      # do 8-bit optimizations, can just compare to 8 literal 0s.

      val = uninitialized UInt64
      while last - first >= int_cmp_len
        first.copy_to(pointerof(val).as(UC*), int_cmp_len)
        if val != int_cmp_zeros
          return true
        end
        first += int_cmp_len
      end
      while first != last
        unless first.value === '0'
          return true
        end
        first += 1
      end
      false
    end

    def is_truncated?(s : Slice(UC)) : Bool forall UC
      is_truncated?(s.to_unsafe, s.to_unsafe + s.size)
    end

    macro parse_eight_digits(p, value, counter, count)
      {{ value }} = {{ value }} &* 100000000 &+ FastFloat.parse_eight_digits_unrolled({{ p }})
      {{ p }} += 8
      {{ counter }} &+= 8
      {{ count }} &+= 8
    end

    macro parse_one_digit(p, value, counter, count)
      {{ value }} = {{ value }} &* 10 &+ {{ p }}.value &- '0'.ord
      {{ p }} += 1
      {{ counter }} &+= 1
      {{ count }} &+= 1
    end

    macro add_native(big, power, value)
      {{ big }}.value.mul({{ power }})
      {{ big }}.value.add({{ value }})
    end

    macro round_up_bigint(big, count)
      # need to round-up the digits, but need to avoid rounding
      # ....9999 to ...10000, which could cause a false halfway point.
      add_native({{ big }}, 10, 1)
      {{ count }} &+= 1
    end

    # parse the significant digits into a big integer
    # NOTE(crystal): returns the new *digits* by value
    def parse_mantissa(result : Bigint*, num : ParsedNumberStringT(UC), max_digits : Int) : Int forall UC
      # try to minimize the number of big integer and scalar multiplication.
      # therefore, try to parse 8 digits at a time, and multiply by the largest
      # scalar value (9 or 19 digits) for each step.
      counter = 0
      digits = 0
      value = Limb.zero
      step = {{ Limb == UInt64 ? 19 : 9 }}

      # process all integer digits.
      p = num.integer.to_unsafe
      pend = p + num.integer.size
      p = skip_zeros(p, pend)
      # process all digits, in increments of step per loop
      while p != pend
        while pend - p >= 8 && step &- counter >= 8 && max_digits &- digits >= 8
          parse_eight_digits(p, value, counter, digits)
        end
        while counter < step && p != pend && digits < max_digits
          parse_one_digit(p, value, counter, digits)
        end
        if digits == max_digits
          # add the temporary value, then check if we've truncated any digits
          add_native(result, Limb.new!(POWERS_OF_TEN_UINT64.unsafe_fetch(counter)), value)
          truncated = is_truncated?(p, pend)
          unless num.fraction.empty?
            truncated ||= is_truncated?(num.fraction)
          end
          if truncated
            round_up_bigint(result, digits)
          end
          return digits
        else
          add_native(result, Limb.new!(POWERS_OF_TEN_UINT64.unsafe_fetch(counter)), value)
          counter = 0
          value = Limb.zero
        end
      end

      # add our fraction digits, if they're available.
      unless num.fraction.empty?
        p = num.fraction.to_unsafe
        pend = p + num.fraction.size
        if digits == 0
          p = skip_zeros(p, pend)
        end
        # process all digits, in increments of step per loop
        while p != pend
          while pend - p >= 8 && step &- counter >= 8 && max_digits &- digits >= 8
            parse_eight_digits(p, value, counter, digits)
          end
          while counter < step && p != pend && digits < max_digits
            parse_one_digit(p, value, counter, digits)
          end
          if digits == max_digits
            # add the temporary value, then check if we've truncated any digits
            add_native(result, Limb.new!(POWERS_OF_TEN_UINT64.unsafe_fetch(counter)), value)
            truncated = is_truncated?(p, pend)
            if truncated
              round_up_bigint(result, digits)
            end
            return digits
          else
            add_native(result, Limb.new!(POWERS_OF_TEN_UINT64.unsafe_fetch(counter)), value)
            counter = 0
            value = Limb.zero
          end
        end
      end

      if counter != 0
        add_native(result, Limb.new!(POWERS_OF_TEN_UINT64.unsafe_fetch(counter)), value)
      end

      digits
    end

    def positive_digit_comp(bigmant : Bigint*, exponent : Int32) : AdjustedMantissa
      bigmant.value.pow10(exponent.to_u32!)
      mantissa, truncated = bigmant.value.hi64
      bias = mantissa_explicit_bits &- minimum_exponent
      power2 = bigmant.value.bit_length &- 64 &+ bias
      answer = AdjustedMantissa.new(power2: power2, mantissa: mantissa)

      answer = round(answer) do |a, shift|
        round_nearest_tie_even(a, shift) do |is_odd, is_halfway, is_above|
          is_above || (is_halfway && truncated) || (is_odd && is_halfway)
        end
      end

      answer
    end

    # the scaling here is quite simple: we have, for the real digits `m * 10^e`,
    # and for the theoretical digits `n * 2^f`. Since `e` is always negative,
    # to scale them identically, we do `n * 2^f * 5^-f`, so we now have `m * 2^e`.
    # we then need to scale by `2^(f- e)`, and then the two significant digits
    # are of the same magnitude.
    def negative_digit_comp(bigmant : Bigint*, am : AdjustedMantissa, exponent : Int32) : AdjustedMantissa
      real_digits = bigmant
      real_exp = exponent

      # get the value of `b`, rounded down, and get a bigint representation of b+h
      am_b = round(am) do |a, shift|
        round_down(a, shift)
      end
      b = to_float(false, am_b)
      theor = to_extended_halfway(b)
      theor_digits = Bigint.new(theor.mantissa)
      theor_exp = theor.power2

      # scale real digits and theor digits to be same power.
      pow2_exp = theor_exp &- real_exp
      pow5_exp = 0_u32 &- real_exp
      if pow5_exp != 0
        theor_digits.pow5(pow5_exp)
      end
      if pow2_exp > 0
        theor_digits.pow2(pow2_exp.to_u32!)
      elsif pow2_exp < 0
        real_digits.value.pow2(0_u32 &- pow2_exp)
      end

      # compare digits, and use it to director rounding
      ord = real_digits.value.compare(pointerof(theor_digits))
      answer = round(am) do |a, shift|
        round_nearest_tie_even(a, shift) do |is_odd, _, _|
          if ord > 0
            true
          elsif ord < 0
            false
          else
            is_odd
          end
        end
      end

      answer
    end

    # parse the significant digits as a big integer to unambiguously round the
    # the significant digits. here, we are trying to determine how to round
    # an extended float representation close to `b+h`, halfway between `b`
    # (the float rounded-down) and `b+u`, the next positive float. this
    # algorithm is always correct, and uses one of two approaches. when
    # the exponent is positive relative to the significant digits (such as
    # 1234), we create a big-integer representation, get the high 64-bits,
    # determine if any lower bits are truncated, and use that to direct
    # rounding. in case of a negative exponent relative to the significant
    # digits (such as 1.2345), we create a theoretical representation of
    # `b` as a big-integer type, scaled to the same binary exponent as
    # the actual digits. we then compare the big integer representations
    # of both, and use that to direct rounding.
    def digit_comp(num : ParsedNumberStringT(UC), am : AdjustedMantissa) : AdjustedMantissa forall UC
      # remove the invalid exponent bias
      am.power2 &-= INVALID_AM_BIAS

      sci_exp = FastFloat.scientific_exponent(num)
      max_digits = self.max_digits
      bigmant = Bigint.new
      digits = parse_mantissa(pointerof(bigmant), num, max_digits)
      # can't underflow, since digits is at most max_digits.
      exponent = sci_exp &+ 1 &- digits
      if exponent >= 0
        positive_digit_comp(pointerof(bigmant), exponent)
      else
        negative_digit_comp(pointerof(bigmant), am, exponent)
      end
    end
  end
end
