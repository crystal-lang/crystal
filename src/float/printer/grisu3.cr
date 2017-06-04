# Grisu3 is ported from the C++ "double-conversions" library.
# The following is their license:
#   Copyright 2012 the V8 project authors. All rights reserved.
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are
#   met:
#
#       * Redistributions of source code must retain the above copyright
#         notice, this list of conditions and the following disclaimer.
#       * Redistributions in binary form must reproduce the above
#         copyright notice, this list of conditions and the following
#         disclaimer in the documentation and/or other materials provided
#         with the distribution.
#       * Neither the name of Google Inc. nor the names of its
#         contributors may be used to endorse or promote products derived
#         from this software without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require "./diy_fp"
require "./ieee"
require "./cached_powers"

module Float::Printer::Grisu3
  extend self

  # Adjusts the last digit of the generated number, and screens out generated
  # solutions that may be inaccurate. A solution may be inaccurate if it is
  # outside the safe interval, or if we cannot prove that it is closer to the
  # input than a neighboring representation of the same length.
  #
  # Input: * buffer pointer containing the digits of too_high / 10^kappa
  #        * the buffer's length
  #        * distance_too_high_w == (too_high - w).frac * unit
  #        * unsafe_interval == (too_high - too_low).frac * unit
  #        * rest = (too_high - buffer * 10^kappa).frac * unit
  #        * ten_kappa = 10^kappa * unit
  #        * unit = the common multiplier
  # Output: returns true if the buffer is guaranteed to contain the closest
  #    representable number to the input.
  #  Modifies the generated digits in the buffer to approach (round towards) w.
  def round_weed(buffer_p, length, distance_too_high_w, unsafe_interval, rest, ten_kappa, unit)
    buffer = buffer_p.to_slice(128)
    small_distance = distance_too_high_w - unit
    big_distance = distance_too_high_w + unit

    # Let w_low  = too_high - big_distance, and
    #     w_high = too_high - small_distance.
    # Note: w_low < w < w_high
    #
    # The real w (* unit) must lie somewhere inside the interval
    # ]w_low; w_high[ (often written as "(w_low; w_high)")
    #
    # Basically the buffer currently contains a number in the unsafe interval
    # ]too_low; too_high[ with too_low < w < too_high
    #
    #  too_high - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #                     ^v 1 unit            ^      ^                 ^      ^
    #  boundary_high ---------------------     .      .                 .      .
    #                     ^v 1 unit            .      .                 .      .
    #   - - - - - - - - - - - - - - - - - - -  +  - - + - - - - - -     .      .
    #                                          .      .         ^       .      .
    #                                          .  big_distance  .       .      .
    #                                          .      .         .       .    rest
    #                              small_distance     .         .       .      .
    #                                          v      .         .       .      .
    #  w_high - - - - - - - - - - - - - - - - - -     .         .       .      .
    #                     ^v 1 unit                   .         .       .      .
    #  w ----------------------------------------     .         .       .      .
    #                     ^v 1 unit                   v         .       .      .
    #  w_low  - - - - - - - - - - - - - - - - - - - - -         .       .      .
    #                                                           .       .      v
    #  buffer --------------------------------------------------+-------+--------
    #                                                           .       .
    #                                                  safe_interval    .
    #                                                           v       .
    #   - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -     .
    #                     ^v 1 unit                                     .
    #  boundary_low -------------------------                     unsafe_interval
    #                     ^v 1 unit                                     v
    #  too_low  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #
    #
    # Note that the value of buffer could lie anywhere inside the range too_low
    # to too_high.
    #
    # boundary_low, boundary_high and w are approximations of the real boundaries
    # and v (the input number). They are guaranteed to be precise up to one unit.
    # In fact the error is guaranteed to be strictly less than one unit.
    #
    # Anything that lies outside the unsafe interval is guaranteed not to round
    # to v when read again.
    # Anything that lies inside the safe interval is guaranteed to round to v
    # when read again.
    # If the number inside the buffer lies inside the unsafe interval but not
    # inside the safe interval then we simply do not know and bail out (returning
    # false).
    #
    # Similarly we have to take into account the imprecision of 'w' when finding
    # the closest representation of 'w'. If we have two potential
    # representations, and one is closer to both w_low and w_high, then we know
    # it is closer to the actual value v.
    #
    # By generating the digits of too_high we got the largest (closest to
    # too_high) buffer that is still in the unsafe interval. In the case where
    # w_high < buffer < too_high we try to decrement the buffer.
    # This way the buffer approaches (rounds towards) w.
    # There are 3 conditions that stop the decrementation process:
    #   1) the buffer is already below w_high
    #   2) decrementing the buffer would make it leave the unsafe interval
    #   3) decrementing the buffer would yield a number below w_high and farther
    #      away than the current number. In other words:
    #              (buffer{-1} < w_high) && w_high - buffer{-1} > buffer - w_high
    # Instead of using the buffer directly we use its distance to too_high.
    # Conceptually rest ~= too_high - buffer
    # We need to do the following tests in this order to avoid over- and
    # underflows.
    _invariant rest <= unsafe_interval
    while (
            rest < small_distance &&    # Negated condition 1
 unsafe_interval - rest >= ten_kappa && # Negated condition 2
 (rest + ten_kappa < small_distance ||  # buffer{-1} > w_high
 small_distance - rest >= rest + ten_kappa - small_distance)
          )
      buffer[length - 1] -= 1
      rest += ten_kappa
    end

    # We have approached w+ as much as possible. We now test if approaching w-
    # would require changing the buffer. If yes, then we have two possible
    # representations close to w, but we cannot decide which one is closer.
    if (
         rest < big_distance &&
         unsafe_interval - rest >= ten_kappa &&
         (rest + ten_kappa < big_distance || big_distance - rest > rest + ten_kappa - big_distance)
       )
      return false
    end

    # Weeding test.
    #   The safe interval is [too_low + 2 ulp; too_high - 2 ulp]
    #   Since too_low = too_high - unsafe_interval this is equivalent to
    #      [too_high - unsafe_interval + 4 ulp; too_high - 2 ulp]
    #   Conceptually we have: rest ~= too_high - buffer
    return (2 * unit <= rest) && (rest <= unsafe_interval - 4 * unit)
  end

  # Generates the digits of input number w.
  # w is a floating-point number (DiyFp), consisting of a significand and an
  # exponent. Its exponent is bounded by kMinimalTargetExponent and
  # kMaximalTargetExponent.
  #       Hence -60 <= w.e() <= -32.
  #
  # Returns false if it fails, in which case the generated digits in the buffer
  # should not be used.
  # Preconditions:
  #  * low, w and high are correct up to 1 ulp (unit in the last place). That
  #    is, their error must be less than a unit of their last digits.
  #  * low.e() == w.e() == high.e()
  #  * low < w < high, and taking into account their error: low~ <= high~
  #  * kMinimalTargetExponent <= w.e() <= kMaximalTargetExponent
  # Postconditions: returns false if procedure fails.
  #   otherwise:
  #     * buffer is not null-terminated, but len contains the number of digits.
  #     * buffer contains the shortest possible decimal digit-sequence
  #       such that LOW < buffer * 10^kappa < HIGH, where LOW and HIGH are the
  #       correct values of low and high (without their error).
  #     * if more than one decimal representation gives the minimal number of
  #       decimal digits then the one closest to W (where W is the correct value
  #       of w) is chosen.
  # Remark: this procedure takes into account the imprecision of its input
  #   numbers. If the precision is not enough to guarantee all the postconditions
  #   then false is returned. This usually happens rarely (~0.5%).
  #
  # Say, for the sake of example, that
  #   w.e() == -48, and w.f() == 0x1234567890abcdef
  # w's value can be computed by w.f() * 2^w.e()
  # We can obtain w's integral digits by simply shifting w.f() by -w.e().
  #  -> w's integral part is 0x1234
  #  w's fractional part is therefore 0x567890abcdef.
  # Printing w's integral part is easy (simply print 0x1234 in decimal).
  # In order to print its fraction we repeatedly multiply the fraction by 10 and
  # get each digit. Example the first digit after the point would be computed by
  #   (0x567890abcdef * 10) >> 48. -> 3
  # The whole thing becomes slightly more complicated because we want to stop
  # once we have enough digits. That is, once the digits inside the buffer
  # represent 'w' we can stop. Everything inside the interval low - high
  # represents w. However we have to pay attention to low, high and w's
  # imprecision.
  def digit_gen(low : DiyFP, w : DiyFP, high : DiyFP, buffer_p) : {Bool, Int32, Int32}
    buffer = buffer_p.to_slice(128)
    _invariant low.exp == w.exp && w.exp == high.exp
    _invariant low.frac + 1 <= high.frac - 1
    _invariant CachedPowers::MIN_TARGET_EXP <= w.exp && w.exp <= CachedPowers::MAX_TARGET_EXP
    # low, w and high are imprecise, but by less than one ulp (unit in the last
    # place).
    # If we remove (resp. add) 1 ulp from low (resp. high) we are certain that
    # the new numbers are outside of the interval we want the final
    # representation to lie in.
    # Inversely adding (resp. removing) 1 ulp from low (resp. high) would yield
    # numbers that are certain to lie in the interval. We will use this fact
    # later on.
    # We will now start by generating the digits within the uncertain
    # interval. Later we will weed out representations that lie outside the safe
    # interval and thus _might_ lie outside the correct interval.
    unit = 1_u64
    too_low = DiyFP.new(low.frac - unit, low.exp)
    too_high = DiyFP.new(high.frac + unit, low.exp)
    # too_low and too_high are guaranteed to lie outside the interval we want the
    # generated number in.
    unsafe_interval = too_high - too_low
    # We now cut the input number into two parts: the integral digits and the
    # fractionals. We will not write any decimal separator though, but adapt
    # kappa instead.
    # Reminder: we are currently computing the digits (stored inside the buffer)
    # such that:   too_low < buffer * 10^kappa < too_high
    # We use too_high for the digit_generation and stop as soon as possible.
    # If we stop early we effectively round down.
    one = DiyFP.new(1_u64 << -w.exp, w.exp)
    # Division by one is a shift.
    integrals = (too_high.frac >> -one.exp).to_u32
    # Modulo by one is an and.
    fractionals = too_high.frac & (one.frac - 1)

    # note: In the C++ version this was: SignificandSize - (-one.e())
    divisor, kappa = CachedPowers.largest_pow10(integrals, DiyFP::SIGNIFICAND_SIZE + one.exp)
    length = 0
    # pp kappa
    # pp divisor

    # Loop invariant: buffer = too_high / 10^kappa  (integer division)
    # The invariant holds for the first iteration: kappa has been initialized
    # with the divisor exponent + 1. And the divisor is the biggest power of ten
    # that is smaller than integrals.
    while kappa > 0
      digit = integrals / divisor
      # pp [digit, kappa]
      _invariant digit <= 9
      buffer[length] = 48_u8 + digit
      length += 1
      integrals %= divisor
      kappa -= 1

      # Note that kappa now equals the exponent of the divisor and that the
      # invariant thus holds again.
      rest = (integrals.to_u64 << -one.exp) + fractionals

      # Invariant: too_high = buffer * 10^kappa + DiyFp(rest, one.e())
      # Reminder: unsafe_interval.e() == one.e()
      if rest < unsafe_interval.frac
        # Rounding down (by not emitting the remaining digits) yields a number
        # that lies within the unsafe interval.
        weeded = round_weed(buffer_p, length, (too_high - w).frac, unsafe_interval.frac, rest, divisor.to_u64 << -one.exp, unit)
        return weeded, kappa, length
      end

      divisor /= 10
    end

    # The integrals have been generated. We are at the point of the decimal
    # separator. In the following loop we simply multiply the remaining digits by
    # 10 and divide by one. We just need to pay attention to multiply associated
    # data (like the interval or 'unit'), too.
    # Note that the multiplication by 10 does not overflow, because w.e >= -60
    # and thus one.e >= -60.
    _invariant one.exp >= -60
    _invariant fractionals < one.frac
    _invariant 0xFFFFFFFFFFFFFFFF / 10 >= one.frac
    loop do
      fractionals *= 10
      unit *= 10
      unsafe_interval = DiyFP.new(unsafe_interval.frac * 10, unsafe_interval.exp)
      digit = (fractionals >> -one.exp).to_i
      _invariant digit <= 9
      buffer[length] = 48_u8 + digit
      length += 1
      fractionals &= one.frac - 1
      kappa -= 1
      if fractionals < unsafe_interval.frac
        weeded = round_weed(buffer_p, length, (too_high - w).frac * unit, unsafe_interval.frac, fractionals, one.frac, unit)
        return weeded, kappa, length
      end
    end
  end

  # Provides a decimal representation of *v*.
  #
  # Returns a `Tuple` of `{status, decimal_exponent, length}`
  # *status* will be true if it succeeds, otherwise the result cannot be
  # trusted.
  # There will be *length* digits inside the buffer (not null-terminated).
  # If the function returns satatus as true true then
  #        v == (buffer * 10^decimal_exponent).to_f
  # The digits in the buffer are the shortest representation possible: no
  # 0.09999999999999999 instead of 0.1. The shorter representation will even be
  # chosen even if the longer one would be closer to *v*.
  # The last digit will be closest to the actual *v*. That is, even if several
  # digits might correctly yield *v* when read again, the closest will be
  # computed.
  def grisu3(v : Float64 | Float32, buffer_p) : {Bool, Int32, Int32}
    buffer = buffer_p.to_slice(128)

    w = DiyFP.from_f_normalized(v)

    # boundary_minus and boundary_plus are the boundaries between v and its
    # closest floating-point neighbors. Any number strictly between
    # boundary_minus and boundary_plus will round to v when convert to a float.
    # Grisu3 will never output representations that lie exactly on a boundary.
    boundaries = IEEE.normalized_boundaries(v)
    _invariant boundaries[:plus].exp == w.exp

    ten_mk, mk = CachedPowers.get_cached_power_for_binary_exponent(w.exp)

    # Note that ten_mk is only an approximation of 10^-k. A DiyFp only contains a
    # 64 bit significand and ten_mk is thus only precise up to 64 bits.
    #
    # The DiyFp::Times procedure rounds its result, and ten_mk is approximated
    # too. The variable scaled_w (as well as scaled_boundary_minus/plus) are now
    # off by a small amount.
    # In fact: scaled_w - w*10^k < 1ulp (unit in the last place) of scaled_w.
    # In other words: let f = scaled_w.f() and e = scaled_w.e(), then
    #           (f-1) * 2^e < w*10^k < (f+1) * 2^e
    scaled_w = w * ten_mk
    _invariant scaled_w.exp == boundaries[:plus].exp + ten_mk.exp + DiyFP::SIGNIFICAND_SIZE

    # In theory it would be possible to avoid some recomputations by computing
    # the difference between w and boundary_minus/plus (a power of 2) and to
    # compute scaled_boundary_minus/plus by subtracting/adding from
    # scaled_w. However the code becomes much less readable and the speed
    # enhancements are not terriffic.
    scaled_boundary_minus = boundaries[:minus] * ten_mk
    scaled_boundary_plus = boundaries[:plus] * ten_mk

    # #digit_gen will generate the digits of scaled_w. Therefore we have
    # v == (scaled_w * 10^-mk).to_f
    # Set decimal_exponent == -mk and pass it to DigitGen. If scaled_w is not an
    # integer than it will be updated. For instance if scaled_w == 1.23 then
    # the buffer will be filled with "123" und the decimal_exponent will be
    # decreased by 2.
    result, kappa, length = digit_gen(scaled_boundary_minus, scaled_w, scaled_boundary_plus, buffer_p)

    decimal_exponent = -mk + kappa
    return result, decimal_exponent, length
  end

  private macro _invariant(exp, file = __FILE__, line = __LINE__)
    {% if !flag?(:release) %}
      unless {{exp}}
        raise "Assertion Failed #{{{file}}}:#{{{line}}}"
      end
    {% end %}
  end
end
