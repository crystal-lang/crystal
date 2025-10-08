require "./float_common"
require "./fast_table"

module Float::FastFloat
  # This will compute or rather approximate w * 5**q and return a pair of 64-bit
  # words approximating the result, with the "high" part corresponding to the
  # most significant bits and the low part corresponding to the least significant
  # bits.
  def self.compute_product_approximation(q : Int64, w : UInt64, bit_precision : Int) : Value128
    power_of_five_128 = Powers::POWER_OF_FIVE_128.to_unsafe

    index = 2 &* (q &- Powers::SMALLEST_POWER_OF_FIVE)
    # For small values of q, e.g., q in [0,27], the answer is always exact
    # because The line value128 firstproduct = full_multiplication(w,
    # power_of_five_128[index]); gives the exact answer.
    firstproduct = w.to_u128! &* power_of_five_128[index]

    precision_mask = bit_precision < 64 ? 0xFFFFFFFFFFFFFFFF_u64.unsafe_shr(bit_precision) : 0xFFFFFFFFFFFFFFFF_u64
    if firstproduct.unsafe_shr(64).bits_set?(precision_mask) # could further guard with  (lower + w < lower)
      # regarding the second product, we only need secondproduct.high, but our
      # expectation is that the compiler will optimize this extra work away if
      # needed.
      secondproduct = w.to_u128! &* power_of_five_128[index &+ 1]
      firstproduct &+= secondproduct.unsafe_shr(64)
    end
    Value128.new(firstproduct)
  end

  module Detail
    # For q in (0,350), we have that
    #  f = (((152170 + 65536) * q ) >> 16);
    # is equal to
    #   floor(p) + q
    # where
    #   p = log(5**q)/log(2) = q * log(5)/log(2)
    #
    # For negative values of q in (-400,0), we have that
    #  f = (((152170 + 65536) * q ) >> 16);
    # is equal to
    #   -ceil(p) + q
    # where
    #   p = log(5**-q)/log(2) = -q * log(5)/log(2)
    def self.power(q : Int32) : Int32
      ((152170 &+ 65536) &* q).unsafe_shr(16) &+ 63
    end
  end

  module BinaryFormat(T, EquivUint)
    # create an adjusted mantissa, biased by the invalid power2
    # for significant digits already multiplied by 10 ** q.
    def compute_error_scaled(q : Int64, w : UInt64, lz : Int) : AdjustedMantissa
      hilz = w.unsafe_shr(63).to_i32! ^ 1
      bias = mantissa_explicit_bits &- minimum_exponent

      AdjustedMantissa.new(
        mantissa: w.unsafe_shl(hilz),
        power2: Detail.power(q.to_i32!) &+ bias &- hilz &- lz &- 62 &+ INVALID_AM_BIAS,
      )
    end

    # w * 10 ** q, without rounding the representation up.
    # the power2 in the exponent will be adjusted by invalid_am_bias.
    def compute_error(q : Int64, w : UInt64) : AdjustedMantissa
      lz = w.leading_zeros_count.to_i32!
      w = w.unsafe_shl(lz)
      product = FastFloat.compute_product_approximation(q, w, mantissa_explicit_bits &+ 3)
      compute_error_scaled(q, product.high, lz)
    end

    # w * 10 ** q
    # The returned value should be a valid ieee64 number that simply need to be
    # packed. However, in some very rare cases, the computation will fail. In such
    # cases, we return an adjusted_mantissa with a negative power of 2: the caller
    # should recompute in such cases.
    def compute_float(q : Int64, w : UInt64) : AdjustedMantissa
      if w == 0 || q < smallest_power_of_ten
        # result should be zero
        return AdjustedMantissa.new(
          power2: 0,
          mantissa: 0,
        )
      end
      if q > largest_power_of_ten
        # we want to get infinity:
        return AdjustedMantissa.new(
          power2: infinite_power,
          mantissa: 0,
        )
      end
      # At this point in time q is in [powers::smallest_power_of_five,
      # powers::largest_power_of_five].

      # We want the most significant bit of i to be 1. Shift if needed.
      lz = w.leading_zeros_count
      w = w.unsafe_shl(lz)

      # The required precision is binary::mantissa_explicit_bits() + 3 because
      # 1. We need the implicit bit
      # 2. We need an extra bit for rounding purposes
      # 3. We might lose a bit due to the "upperbit" routine (result too small,
      # requiring a shift)

      product = FastFloat.compute_product_approximation(q, w, mantissa_explicit_bits &+ 3)
      # The computed 'product' is always sufficient.
      # Mathematical proof:
      # Noble Mushtak and Daniel Lemire, Fast Number Parsing Without Fallback (to
      # appear) See script/mushtak_lemire.py

      # The "compute_product_approximation" function can be slightly slower than a
      # branchless approach: value128 product = compute_product(q, w); but in
      # practice, we can win big with the compute_product_approximation if its
      # additional branch is easily predicted. Which is best is data specific.
      upperbit = product.high.unsafe_shr(63).to_i32!
      shift = upperbit &+ 64 &- mantissa_explicit_bits &- 3

      mantissa = product.high.unsafe_shr(shift)

      power2 = (Detail.power(q.to_i32!) &+ upperbit &- lz &- minimum_exponent).to_i32!
      if power2 <= 0 # we have a subnormal?
        # Here have that answer.power2 <= 0 so -answer.power2 >= 0
        if 1 &- power2 >= 64 # if we have more than 64 bits below the minimum exponent, you have a zero for sure.
          # result should be zero
          return AdjustedMantissa.new(
            power2: 0,
            mantissa: 0,
          )
        end
        # next line is safe because -answer.power2 + 1 < 64
        mantissa = mantissa.unsafe_shr(1 &- power2)
        # Thankfully, we can't have both "round-to-even" and subnormals because
        # "round-to-even" only occurs for powers close to 0.
        mantissa &+= mantissa & 1
        mantissa = mantissa.unsafe_shr(1)
        # There is a weird scenario where we don't have a subnormal but just.
        # Suppose we start with 2.2250738585072013e-308, we end up
        # with 0x3fffffffffffff x 2^-1023-53 which is technically subnormal
        # whereas 0x40000000000000 x 2^-1023-53  is normal. Now, we need to round
        # up 0x3fffffffffffff x 2^-1023-53  and once we do, we are no longer
        # subnormal, but we can only know this after rounding.
        # So we only declare a subnormal if we are smaller than the threshold.
        power2 = mantissa < 1_u64.unsafe_shl(mantissa_explicit_bits) ? 0 : 1
        return AdjustedMantissa.new(power2: power2, mantissa: mantissa)
      end

      # usually, we round *up*, but if we fall right in between and and we have an
      # even basis, we need to round down
      # We are only concerned with the cases where 5**q fits in single 64-bit word.
      if product.low <= 1 && q >= min_exponent_round_to_even && q <= max_exponent_round_to_even && mantissa & 3 == 1
        # we may fall between two floats!
        # To be in-between two floats we need that in doing
        #   answer.mantissa = product.high >> (upperbit + 64 -
        #   binary::mantissa_explicit_bits() - 3);
        # ... we dropped out only zeroes. But if this happened, then we can go
        # back!!!
        if mantissa.unsafe_shl(shift) == product.high
          mantissa &= ~1_u64 # flip it so that we do not round up
        end
      end

      mantissa &+= mantissa & 1 # round up
      mantissa = mantissa.unsafe_shr(1)
      if mantissa >= 2_u64.unsafe_shl(mantissa_explicit_bits)
        mantissa = 1_u64.unsafe_shl(mantissa_explicit_bits)
        power2 &+= 1 # undo previous addition
      end

      mantissa &= ~(1_u64.unsafe_shl(mantissa_explicit_bits))
      if power2 >= infinite_power # infinity
        return AdjustedMantissa.new(
          power2: infinite_power,
          mantissa: 0,
        )
      end
      AdjustedMantissa.new(power2: power2, mantissa: mantissa)
    end
  end
end
