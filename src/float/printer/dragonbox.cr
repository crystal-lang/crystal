# Source port of Dragonbox's reference implementation in C++.
#
# The following is their license:
#
#   Copyright 2020-2021 Junekey Jeon
#
#   The contents of this file may be used under the terms of
#   the Apache License v2.0 with LLVM Exceptions.
#
#      (See accompanying file LICENSE-Apache or copy at
#       https://llvm.org/foundation/relicensing/LICENSE.txt)
#
#   Alternatively, the contents of this file may be used under the terms of
#   the Boost Software License, Version 1.0.
#      (See accompanying file LICENSE-Boost or copy at
#       https://www.boost.org/LICENSE_1_0.txt)
#
#   Unless required by applicable law or agreed to in writing, this software
#   is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#   KIND, either express or implied.
module Float::Printer::Dragonbox
  # Current revision: https://github.com/jk-jeon/dragonbox/tree/33a9e021290d529bcb41773be2c7c3c91726a9cb
  #
  # Assumes the following policies:
  #
  # * `jkj::dragonbox::policy::sign::ignore`
  # * `jkj::dragonbox::policy::trailing_zero::ignore`
  # * `jkj::dragonbox::policy::decimal_to_binary_rounding::nearest_to_even` (default)
  # * `jkj::dragonbox::policy::binary_to_decimal_rounding::to_even` (default)
  # * `jkj::dragonbox::policy::cache::full` (default)

  # Utilities for wide unsigned integer arithmetic.
  private module WUInt
    # TODO: use built-in integer type
    record UInt128, high : UInt64, low : UInt64 do
      def unsafe_add!(n : UInt64) : self
        sum = @low &+ n
        @high &+= (sum < @low ? 1 : 0)
        @low = sum
        self
      end
    end

    def self.umul64(x : UInt32, y : UInt32) : UInt64
      x.to_u64 &* y
    end

    # Get 128-bit result of multiplication of two 64-bit unsigned integers.
    def self.umul128(x : UInt64, y : UInt64) : UInt128
      a = (x >> 32).to_u32!
      b = x.to_u32!
      c = (y >> 32).to_u32!
      d = y.to_u32!

      ac = umul64(a, c)
      bc = umul64(b, c)
      ad = umul64(a, d)
      bd = umul64(b, d)

      intermediate = (bd >> 32) &+ ad.to_u32! &+ bc.to_u32!

      UInt128.new(
        high: ac &+ (intermediate >> 32) &+ (ad >> 32) &+ (bc >> 32),
        low: (intermediate << 32) &+ bd.to_u32!,
      )
    end

    def self.umul128_upper64(x : UInt64, y : UInt64) : UInt64
      a = (x >> 32).to_u32!
      b = x.to_u32!
      c = (y >> 32).to_u32!
      d = y.to_u32!

      ac = umul64(a, c)
      bc = umul64(b, c)
      ad = umul64(a, d)
      bd = umul64(b, d)

      intermediate = (bd >> 32) &+ ad.to_u32! &+ bc.to_u32!
      ac &+ (intermediate >> 32) &+ (ad >> 32) &+ (bc >> 32)
    end

    # Get upper 128-bits of multiplication of a 64-bit unsigned integer and a 128-bit unsigned integer.
    def self.umul192_upper128(x : UInt64, y : UInt128) : UInt128
      r = umul128(x, y.high)
      r.unsafe_add!(umul128_upper64(x, y.low))
      r
    end

    # Get upper 64-bits of multiplication of a 32-bit unsigned integer and a 64-bit unsigned integer.
    def self.umul96_upper64(x : UInt32, y : UInt64) : UInt64
      yh = (y >> 32).to_u32!
      yl = y.to_u32!

      xyh = umul64(x, yh)
      xyl = umul64(x, yl)

      xyh &+ (xyl >> 32)
    end

    # Get lower 128-bits of multiplication of a 64-bit unsigned integer and a 128-bit unsigned integer.
    def self.umul192_lower128(x : UInt64, y : UInt128) : UInt128
      high = x &* y.high
      high_low = umul128(x, y.low)
      UInt128.new(
        high: high &+ high_low.high,
        low: high_low.low,
      )
    end

    # Get lower 64-bits of multiplication of a 32-bit unsigned integer and a 64-bit unsigned integer.
    def self.umul96_lower64(x : UInt32, y : UInt64) : UInt64
      y &* x
    end
  end

  # Utilities for fast log computation.
  private module Log
    def self.floor_log10_pow2(e : Int)
      # Precondition: `-2620 <= e <= 2620`
      (e &* 315653) >> 20
    end

    def self.floor_log2_pow10(e : Int)
      # Precondition: `-1233 <= e <= 1233`
      (e &* 1741647) >> 19
    end

    def self.floor_log10_pow2_minus_log10_4_over_3(e : Int)
      # Precondition: `-2985 <= e <= 2936`
      (e &* 631305 &- 261663) >> 21
    end
  end

  # Utilities for fast divisibility tests.
  private module Div
    CACHED_POWERS_OF_5_TABLE_U32 = [
      {0x00000001_u32, 0xffffffff_u32},
      {0xcccccccd_u32, 0x33333333_u32},
      {0xc28f5c29_u32, 0x0a3d70a3_u32},
      {0x26e978d5_u32, 0x020c49ba_u32},
      {0x3afb7e91_u32, 0x0068db8b_u32},
      {0x0bcbe61d_u32, 0x0014f8b5_u32},
      {0x68c26139_u32, 0x000431bd_u32},
      {0xae8d46a5_u32, 0x0000d6bf_u32},
      {0x22e90e21_u32, 0x00002af3_u32},
      {0x3a2e9c6d_u32, 0x00000897_u32},
      {0x3ed61f49_u32, 0x000001b7_u32},
      {0x0c913975_u32, 0x00000057_u32},
      {0xcf503eb1_u32, 0x00000011_u32},
      {0xf6433fbd_u32, 0x00000003_u32},
      {0x3140a659_u32, 0x00000002_u32},
      {0x70402145_u32, 0x00000009_u32},
      {0x7cd9a041_u32, 0x00000001_u32},
      {0xe5c5200d_u32, 0x00000001_u32},
      {0xfac10669_u32, 0x00000005_u32},
      {0x6559ce15_u32, 0x00000001_u32},
      {0xaddec2d1_u32, 0x00000002_u32},
      {0x892c8d5d_u32, 0x00000003_u32},
      {0x1b6f4f79_u32, 0x00000001_u32},
      {0x6be30fe5_u32, 0x00000001_u32},
    ]

    CACHED_POWERS_OF_5_TABLE_U64 = [
      {0x0000000000000001_u64, 0xffffffffffffffff_u64},
      {0xcccccccccccccccd_u64, 0x3333333333333333_u64},
      {0x8f5c28f5c28f5c29_u64, 0x0a3d70a3d70a3d70_u64},
      {0x1cac083126e978d5_u64, 0x020c49ba5e353f7c_u64},
      {0xd288ce703afb7e91_u64, 0x0068db8bac710cb2_u64},
      {0x5d4e8fb00bcbe61d_u64, 0x0014f8b588e368f0_u64},
      {0x790fb65668c26139_u64, 0x000431bde82d7b63_u64},
      {0xe5032477ae8d46a5_u64, 0x0000d6bf94d5e57a_u64},
      {0xc767074b22e90e21_u64, 0x00002af31dc46118_u64},
      {0x8e47ce423a2e9c6d_u64, 0x0000089705f4136b_u64},
      {0x4fa7f60d3ed61f49_u64, 0x000001b7cdfd9d7b_u64},
      {0x0fee64690c913975_u64, 0x00000057f5ff85e5_u64},
      {0x3662e0e1cf503eb1_u64, 0x000000119799812d_u64},
      {0xa47a2cf9f6433fbd_u64, 0x0000000384b84d09_u64},
      {0x54186f653140a659_u64, 0x00000000b424dc35_u64},
      {0x7738164770402145_u64, 0x0000000024075f3d_u64},
      {0xe4a4d1417cd9a041_u64, 0x000000000734aca5_u64},
      {0xc75429d9e5c5200d_u64, 0x000000000170ef54_u64},
      {0xc1773b91fac10669_u64, 0x000000000049c977_u64},
      {0x26b172506559ce15_u64, 0x00000000000ec1e4_u64},
      {0xd489e3a9addec2d1_u64, 0x000000000002f394_u64},
      {0x90e860bb892c8d5d_u64, 0x000000000000971d_u64},
      {0x502e79bf1b6f4f79_u64, 0x0000000000001e39_u64},
      {0xdcd618596be30fe5_u64, 0x000000000000060b_u64},
    ]

    module DIVIDE_BY_POW10_INFO_F32
      MAGIC_NUMBER = 6554_u32
      SHIFT_AMOUNT =       16
    end

    module DIVIDE_BY_POW10_INFO_F64
      MAGIC_NUMBER = 656_u32
      SHIFT_AMOUNT =      16
    end

    # N == 1
    def self.check_divisibility_and_divide_by_pow10_k1(n : UInt32)
      n &*= DIVIDE_BY_POW10_INFO_F32::MAGIC_NUMBER

      # Mask for the lowest (divisibility_check_bits)-bits.
      divisibility_check_bits = DIVIDE_BY_POW10_INFO_F32::SHIFT_AMOUNT
      comparison_mask = ~(UInt32::MAX << divisibility_check_bits)
      result = n & comparison_mask < DIVIDE_BY_POW10_INFO_F32::MAGIC_NUMBER

      n >>= divisibility_check_bits
      {n, result}
    end

    # N == 2
    def self.check_divisibility_and_divide_by_pow10_k2(n : UInt32)
      n &*= DIVIDE_BY_POW10_INFO_F64::MAGIC_NUMBER

      # Mask for the lowest (divisibility_check_bits)-bits.
      divisibility_check_bits = DIVIDE_BY_POW10_INFO_F64::SHIFT_AMOUNT
      comparison_mask = ~(UInt32::MAX << divisibility_check_bits)
      result = n & comparison_mask < DIVIDE_BY_POW10_INFO_F64::MAGIC_NUMBER

      n >>= divisibility_check_bits
      {n, result}
    end
  end

  private module ImplInfoMethods(D)
    def extract_exponent_bits(u : D::CarrierUInt)
      exponent_bits_mask = ~(UInt32::MAX << D::EXPONENT_BITS)
      ((u >> D::SIGNIFICAND_BITS) & exponent_bits_mask).to_u32!
    end

    def remove_exponent_bits(u : D::CarrierUInt, exponent_bits)
      u ^ (D::CarrierUInt.new!(exponent_bits) << D::SIGNIFICAND_BITS)
    end

    def remove_sign_bit_and_shift(u : D::CarrierUInt)
      u << 1
    end

    def check_divisibility_and_divide_by_pow10(n : UInt32)
      {% if D::KAPPA == 1 %}
        Div.check_divisibility_and_divide_by_pow10_k1(n)
      {% elsif D::KAPPA == 2 %}
        Div.check_divisibility_and_divide_by_pow10_k2(n)
      {% else %}
        {% raise "Expected kappa == 1 or kappa == 2" %}
      {% end %}
    end
  end

  private module ImplInfo_Float32
    extend ImplInfoMethods(self)

    SIGNIFICAND_BITS =   23
    EXPONENT_BITS    =    8
    MIN_EXPONENT     = -126
    MAX_EXPONENT     =  127
    EXPONENT_BIAS    = -127
    DECIMAL_DIGITS   =    9

    alias CarrierUInt = UInt32
    CARRIER_BITS = 32

    KAPPA =   1
    MIN_K = -31
    # MAX_K = 46
    CACHE_BITS = 64

    SHORTER_INTERVAL_TIE_LOWER_THRESHOLD                = -35
    SHORTER_INTERVAL_TIE_UPPER_THRESHOLD                = -35
    CASE_SHORTER_INTERVAL_LEFT_ENDPOINT_LOWER_THRESHOLD =   2
    CASE_SHORTER_INTERVAL_LEFT_ENDPOINT_UPPER_THRESHOLD =   3

    BIG_DIVISOR   = 10_u32 ** (KAPPA + 1)
    SMALL_DIVISOR = 10_u32 ** KAPPA
  end

  private module ImplInfo_Float64
    extend ImplInfoMethods(self)

    SIGNIFICAND_BITS =    52
    EXPONENT_BITS    =    11
    MIN_EXPONENT     = -1022
    MAX_EXPONENT     =  1023
    EXPONENT_BIAS    = -1023
    DECIMAL_DIGITS   =    17

    alias CarrierUInt = UInt64
    CARRIER_BITS = 64

    KAPPA =    2
    MIN_K = -292
    # MAX_K = 326
    CACHE_BITS = 128

    SHORTER_INTERVAL_TIE_LOWER_THRESHOLD                = -77
    SHORTER_INTERVAL_TIE_UPPER_THRESHOLD                = -77
    CASE_SHORTER_INTERVAL_LEFT_ENDPOINT_LOWER_THRESHOLD =   2
    CASE_SHORTER_INTERVAL_LEFT_ENDPOINT_UPPER_THRESHOLD =   3

    BIG_DIVISOR   = 10_u32 ** (KAPPA + 1)
    SMALL_DIVISOR = 10_u32 ** KAPPA
  end

  private module Impl(F, ImplInfo)
    def self.prefer_round_down?(significand)
      significand % 2 != 0
    end

    def self.compute_nearest_normal(two_fc, exponent, is_closed)
      # Step 1: Schubfach multiplier calculation

      # Compute k and beta.
      minus_k = Log.floor_log10_pow2(exponent) - ImplInfo::KAPPA
      cache = ImplInfo.get_cache(-minus_k)
      beta = exponent + Log.floor_log2_pow10(-minus_k)

      # Compute zi and deltai.
      # 10^kappa <= deltai < 10^(kappa + 1)
      deltai = compute_delta(cache, beta)
      # For the case of binary32, the result of integer check is not correct for
      # 29711844 * 2^-82
      # = 6.1442653300000000008655037797566933477355632930994033813476... * 10^-18
      # and 29711844 * 2^-81
      # = 1.2288530660000000001731007559513386695471126586198806762695... * 10^-17,
      # and they are the unique counterexamples. However, since 29711844 is even,
      # this does not cause any problem for the endpoints calculations; it can only
      # cause a problem when we need to perform integer check for the center.
      # Fortunately, with these inputs, that branch is never executed, so we are fine.
      zi, is_z_integer = compute_mul((two_fc | 1) << beta, cache)

      # Step 2: Try larger divisor
      big_divisor = ImplInfo::BIG_DIVISOR
      small_divisor = ImplInfo::SMALL_DIVISOR

      significand = zi // big_divisor
      r = (zi - significand * big_divisor).to_u32!

      case r
      when .>(deltai)
        # do nothing
      when .<(deltai)
        # Exclude the right endpoint if necessary.
        if r == 0 && is_z_integer && !is_closed
          significand -= 1
          r = big_divisor
        else
          ret_exponent = minus_k + ImplInfo::KAPPA + 1
          return {significand, ret_exponent}
        end
      else
        # r == deltai; compare fractional parts.
        xi_parity, x_is_integer = compute_mul_parity(two_fc - 1, cache, beta)

        if xi_parity || (x_is_integer && is_closed)
          ret_exponent = minus_k + ImplInfo::KAPPA + 1
          return {significand, ret_exponent}
        end
      end

      # Step 3: Find the significand with the smaller divisor
      significand *= 10
      ret_exponent = minus_k + ImplInfo::KAPPA

      dist = r - deltai // 2 + small_divisor // 2
      approx_y_parity = ((dist ^ (small_divisor // 2)) & 1) != 0

      # Is dist divisible by 10^kappa?
      dist, divisible_by_small_divisor = ImplInfo.check_divisibility_and_divide_by_pow10(dist)

      # Add dist / 10^kappa to the significand.
      significand += dist

      if divisible_by_small_divisor
        # Check z^(f) >= epsilon^(f).
        # We have either yi == zi - epsiloni or yi == (zi - epsiloni) - 1,
        # where yi == zi - epsiloni if and only if z^(f) >= epsilon^(f).
        # Since there are only 2 possibilities, we only need to care about the parity.
        # Also, zi and r should have the same parity since the divisor
        # is an even number.
        yi_parity, is_y_integer = compute_mul_parity(two_fc, cache, beta)
        if yi_parity != approx_y_parity
          significand -= 1
        elsif prefer_round_down?(significand) && is_y_integer
          # If z^(f) >= epsilon^(f), we might have a tie
          # when z^(f) == epsilon^(f), or equivalently, when y is an integer.
          # For tie-to-up case, we can just choose the upper one.
          significand -= 1
        end
      end

      {significand, ret_exponent}
    end

    def self.compute_nearest_shorter(exponent)
      # Compute k and beta.
      minus_k = Log.floor_log10_pow2_minus_log10_4_over_3(exponent)
      beta = exponent + Log.floor_log2_pow10(-minus_k)

      # Compute xi and zi.
      cache = ImplInfo.get_cache(-minus_k)

      xi = compute_left_endpoint_for_shorter_interval_case(cache, beta)
      zi = compute_right_endpoint_for_shorter_interval_case(cache, beta)

      # If we don't accept the left endpoint or
      # if the left endpoint is not an integer, increase it.
      xi += 1 if !is_left_endpoint_integer_shorter_interval?(exponent)

      # Try bigger divisor.
      significand = zi // 10

      # If succeed, return.
      if significand * 10 >= xi
        ret_exponent = minus_k + 1
        return {significand, ret_exponent}
      end

      # Otherwise, compute the round-up of y
      significand = compute_round_up_for_shorter_interval_case(cache, beta)
      ret_exponent = minus_k

      # When tie occurs, choose one of them according to the rule.
      if prefer_round_down?(significand) && (ImplInfo::SHORTER_INTERVAL_TIE_LOWER_THRESHOLD <= exponent <= ImplInfo::SHORTER_INTERVAL_TIE_UPPER_THRESHOLD)
        significand -= 1
      elsif significand < xi
        significand += 1
      end

      {significand, ret_exponent}
    end

    def self.compute_mul(u, cache) # : {result: ImplInfo::CarrierUInt, is_integer: Bool}
      {% if F == Float32 %}
        r = WUInt.umul96_upper64(u, cache)
        {
          ImplInfo::CarrierUInt.new!(r >> 32),
          ImplInfo::CarrierUInt.new!(r) == 0,
        }
      {% else %}
        # F == Float64
        r = WUInt.umul192_upper128(u, cache)
        {r.high, r.low == 0}
      {% end %}
    end

    def self.compute_delta(cache, beta) : UInt32
      {% if F == Float32 %}
        (cache >> (ImplInfo::CACHE_BITS - 1 - beta)).to_u32!
      {% else %}
        # F == Float64
        (cache.high >> (ImplInfo::CARRIER_BITS - 1 - beta)).to_u32!
      {% end %}
    end

    def self.compute_mul_parity(two_f, cache, beta) # : {parity: Bool, is_integer: Bool}
      {% if F == Float32 %}
        r = WUInt.umul96_lower64(two_f, cache)
        {
          ((r >> (64 - beta)) & 1) != 0,
          UInt32.new!(r >> (32 - beta)) == 0,
        }
      {% else %}
        # F == Float64
        r = WUInt.umul192_lower128(two_f, cache)
        {
          ((r.high >> (64 - beta)) & 1) != 0,
          (r.high << beta) | (r.low >> (64 - beta)) == 0,
        }
      {% end %}
    end

    def self.compute_left_endpoint_for_shorter_interval_case(cache, beta)
      significand_bits = ImplInfo::SIGNIFICAND_BITS

      ImplInfo::CarrierUInt.new!(
        {% if F == Float32 %}
          (cache - (cache >> (significand_bits + 2))) >> (ImplInfo::CACHE_BITS - significand_bits - 1 - beta)
        {% else %}
          # F == Float64
          (cache.high - (cache.high >> (significand_bits + 2))) >> (ImplInfo::CARRIER_BITS - significand_bits - 1 - beta)
        {% end %}
      )
    end

    def self.compute_right_endpoint_for_shorter_interval_case(cache, beta)
      significand_bits = ImplInfo::SIGNIFICAND_BITS

      ImplInfo::CarrierUInt.new!(
        {% if F == Float32 %}
          (cache + (cache >> (significand_bits + 1))) >> (ImplInfo::CACHE_BITS - significand_bits - 1 - beta)
        {% else %}
          # F == Float64
          (cache.high + (cache.high >> (significand_bits + 1))) >> (ImplInfo::CARRIER_BITS - significand_bits - 1 - beta)
        {% end %}
      )
    end

    def self.compute_round_up_for_shorter_interval_case(cache, beta)
      significand_bits = ImplInfo::SIGNIFICAND_BITS

      {% if F == Float32 %}
        (ImplInfo::CarrierUInt.new!(cache >> (ImplInfo::CACHE_BITS - significand_bits - 2 - beta)) + 1) // 2
      {% else %}
        # F == Float64
        ((cache.high >> (ImplInfo::CARRIER_BITS - significand_bits - 2 - beta)) + 1) // 2
      {% end %}
    end

    def self.is_left_endpoint_integer_shorter_interval?(exponent)
      ImplInfo::CASE_SHORTER_INTERVAL_LEFT_ENDPOINT_LOWER_THRESHOLD <=
        exponent <= ImplInfo::CASE_SHORTER_INTERVAL_LEFT_ENDPOINT_UPPER_THRESHOLD
    end

    def self.to_decimal(signed_significand_bits, exponent_bits)
      two_fc = ImplInfo.remove_sign_bit_and_shift(signed_significand_bits)
      exponent = exponent_bits.to_i

      # Is the input a normal number?
      if exponent != 0
        exponent += ImplInfo::EXPONENT_BIAS - ImplInfo::SIGNIFICAND_BITS

        # Shorter interval case; proceed like Schubfach.
        # One might think this condition is wrong, since when exponent_bits == 1
        # and two_fc == 0, the interval is actually regular. However, it turns out
        # that this seemingly wrong condition is actually fine, because the end
        # result is anyway the same.
        #
        # [binary32]
        # (fc-1/2) * 2^e = 1.175'494'28... * 10^-38
        # (fc-1/4) * 2^e = 1.175'494'31... * 10^-38
        #    fc    * 2^e = 1.175'494'35... * 10^-38
        # (fc+1/2) * 2^e = 1.175'494'42... * 10^-38
        #
        # Hence, shorter_interval_case will return 1.175'494'4 * 10^-38.
        # 1.175'494'3 * 10^-38 is also a correct shortest representation that will
        # be rejected if we assume shorter interval, but 1.175'494'4 * 10^-38 is
        # closer to the true value so it doesn't matter.
        #
        # [binary64]
        # (fc-1/2) * 2^e = 2.225'073'858'507'201'13... * 10^-308
        # (fc-1/4) * 2^e = 2.225'073'858'507'201'25... * 10^-308
        #    fc    * 2^e = 2.225'073'858'507'201'38... * 10^-308
        # (fc+1/2) * 2^e = 2.225'073'858'507'201'63... * 10^-308
        #
        # Hence, shorter_interval_case will return 2.225'073'858'507'201'4 * 10^-308.
        # This is indeed of the shortest length, and it is the unique one
        # closest to the true value among valid representations of the same length.
        return compute_nearest_shorter(exponent) if two_fc == 0

        two_fc |= two_fc.class.new(1) << (ImplInfo::SIGNIFICAND_BITS + 1)
      else # Is the input a subnormal number?
        exponent = ImplInfo::MIN_EXPONENT - ImplInfo::SIGNIFICAND_BITS
      end

      compute_nearest_normal(two_fc, exponent, signed_significand_bits % 2 == 0)
    end
  end

  {% for f, uint in {Float32 => UInt32, Float64 => UInt64} %}
    # Provides a decimal representation of *x*.
    #
    # Returns a `Tuple` of `{significand, decimal_exponent}` such that
    # `x == significand * 10.0 ** decimal_exponent`. This decimal representation
    # is the shortest possible while still maintaining the round-trip guarantee.
    # There may be trailing zeros in `significand`.
    def self.to_decimal(x : {{ f }}) : Tuple({{ uint }}, Int32)
      br = x.unsafe_as({{ uint }})
      exponent_bits = ImplInfo_{{ f }}.extract_exponent_bits(br)
      s = ImplInfo_{{ f }}.remove_exponent_bits(br, exponent_bits)
      Impl({{ f }}, ImplInfo_{{ f }}).to_decimal(s, exponent_bits)
    end
  {% end %}
end

require "./dragonbox_cache"
