# IEEE is ported from the C++ "double-conversions" library.
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

module Float::Printer::IEEE
  extend self

  EXPONENT_MASK_64             = 0x7FF0000000000000_u64
  SIGNIFICAND_MASK_64          = 0x000FFFFFFFFFFFFF_u64
  HIDDEN_BIT_64                = 0x0010000000000000_u64
  PHYSICAL_SIGNIFICAND_SIZE_64 =                     52 # Excludes the hidden bit
  SIGNIFICAND_SIZE_64          =                     53
  EXPONENT_BIAS_64             = 0x3FF + PHYSICAL_SIGNIFICAND_SIZE_64
  DENORMAL_EXPONENT_64         = -EXPONENT_BIAS_64 + 1
  SIGN_MASK_64                 = 0x8000000000000000_u64

  EXPONENT_MASK_32             = 0x7F800000_u32
  SIGNIFICAND_MASK_32          = 0x007FFFFF_u32
  HIDDEN_BIT_32                = 0x00800000_u32
  PHYSICAL_SIGNIFICAND_SIZE_32 =             23 # Excludes the hidden bit
  SIGNIFICAND_SIZE_32          =             24
  EXPONENT_BIAS_32             = 0x7F + PHYSICAL_SIGNIFICAND_SIZE_32
  DENORMAL_EXPONENT_32         = -EXPONENT_BIAS_32 + 1
  SIGN_MASK_32                 = 0x80000000_u32

  def to_uint(v : Float64)
    v.unsafe_as(UInt64)
  end

  def to_uint(v : Float32)
    v.unsafe_as(UInt32)
  end

  def sign(d64 : UInt64)
    (d64 & SIGN_MASK_64) == 0 ? 1 : -1
  end

  def sign(d32 : UInt32)
    (d32 & SIGN_MASK_32) == 0 ? 1 : -1
  end

  def special?(d64 : UInt64)
    (d64 & EXPONENT_MASK_64) == EXPONENT_MASK_64
  end

  def special?(d32 : UInt32)
    (d32 & EXPONENT_MASK_32) == EXPONENT_MASK_32
  end

  def inf?(d64 : UInt64)
    special?(d64) && (d64 & SIGNIFICAND_MASK_64 == 0)
  end

  def inf?(d32 : UInt32)
    special?(d32) && (d32 & SIGNIFICAND_MASK_32 == 0)
  end

  def nan?(d64 : UInt64)
    special?(d64) && (d64 & SIGNIFICAND_MASK_64 != 0)
  end

  def nan?(d32 : UInt32)
    special?(d32) && (d32 & SIGNIFICAND_MASK_32 != 0)
  end

  # Computes the two boundaries of *v*.
  # The bigger boundary (m_plus) is normalized. The lower boundary has the same
  # exponent as m_plus.
  # Precondition: the value encoded by this Flaot must be greater than 0.
  def normalized_boundaries(v : Float64)
    _invariant v > 0
    w = DiyFP.from_f(v)
    m_plus = DiyFP.new((w.frac << 1) + 1, w.exp - 1).normalize

    d64 = to_uint(v)

    # The boundary is closer if the significand is of the form f == 2^p-1 then
    # the lower boundary is closer.
    # Think of v = 1000e10 and v- = 9999e9.
    # Then the boundary (== (v - v-)/2) is not just at a distance of 1e9 but
    # at a distance of 1e8.
    # The only exception is for the smallest normal: the largest denormal is
    # at the same distance as its successor.
    # Note: denormals have the same exponent as the smallest normals.
    physical_significand_is_zero = (d64 & SIGNIFICAND_MASK_64) == 0

    lower_bound_closer = physical_significand_is_zero && (exponent(d64) != DENORMAL_EXPONENT_64)
    calcualted_exp = exponent(d64)
    calc_denormal = denormal?(d64)
    f, e = if lower_bound_closer
             {(w.frac << 2) - 1, w.exp - 2}
           else
             {(w.frac << 1) - 1, w.exp - 1}
           end
    m_minus = DiyFP.new(f << (e - m_plus.exp), m_plus.exp)
    return {minus: m_minus, plus: m_plus}
  end

  def normalized_boundaries(v : Float32)
    _invariant v > 0
    w = DiyFP.from_f(v)
    m_plus = DiyFP.new((w.frac << 1) + 1, w.exp - 1).normalize

    d32 = to_uint(v)

    physical_significand_is_zero = (d32 & SIGNIFICAND_MASK_32) == 0

    lower_bound_closer = physical_significand_is_zero && (exponent(d32) != DENORMAL_EXPONENT_32)
    calcualted_exp = exponent(d32)
    calc_denormal = denormal?(d32)
    f, e = if lower_bound_closer
             {(w.frac << 2) - 1, w.exp - 2}
           else
             {(w.frac << 1) - 1, w.exp - 1}
           end
    m_minus = DiyFP.new(f << (e - m_plus.exp), m_plus.exp)
    return {minus: m_minus, plus: m_plus}
  end

  def frac_and_exp(v : Float64)
    d64 = to_uint(v)
    _invariant (d64 & EXPONENT_MASK_64) != EXPONENT_MASK_64

    if (d64 & EXPONENT_MASK_64) == 0 # denormal float
      frac = d64 & SIGNIFICAND_MASK_64
      exp = 1 - EXPONENT_BIAS_64
    else
      frac = (d64 & SIGNIFICAND_MASK_64) + HIDDEN_BIT_64
      exp = (((d64 & EXPONENT_MASK_64) >> PHYSICAL_SIGNIFICAND_SIZE_64) - EXPONENT_BIAS_64).to_i
    end

    {frac, exp}
  end

  def frac_and_exp(v : Float32)
    d32 = to_uint(v)
    _invariant (d32 & EXPONENT_MASK_32) != EXPONENT_MASK_32

    if (d32 & EXPONENT_MASK_32) == 0 # denormal float
      frac = d32 & SIGNIFICAND_MASK_32
      exp = 1 - EXPONENT_BIAS_32
    else
      frac = (d32 & SIGNIFICAND_MASK_32) + HIDDEN_BIT_32
      exp = (((d32 & EXPONENT_MASK_32) >> PHYSICAL_SIGNIFICAND_SIZE_32) - EXPONENT_BIAS_32).to_i
    end

    {frac.to_u64, exp}
  end

  private def denormal?(d64 : UInt64) : Bool
    (d64 & EXPONENT_MASK_64) == 0
  end

  private def denormal?(d32 : UInt32) : Bool
    (d32 & EXPONENT_MASK_32) == 0
  end

  private def exponent(d64 : UInt64)
    return DENORMAL_EXPONENT_64 if denormal?(d64)
    baised_e = ((d64 & EXPONENT_MASK_64) >> PHYSICAL_SIGNIFICAND_SIZE_64).to_i
    baised_e - EXPONENT_BIAS_64
  end

  private def exponent(d32 : UInt32)
    return DENORMAL_EXPONENT_32 if denormal?(d32)
    baised_e = ((d32 & EXPONENT_MASK_32) >> PHYSICAL_SIGNIFICAND_SIZE_32).to_i
    baised_e - EXPONENT_BIAS_32
  end

  private macro _invariant(exp, file = __FILE__, line = __LINE__)
    {% if !flag?(:release) %}
      unless {{exp}}
        raise "Assertion Failed #{{{file}}}:#{{{line}}}"
      end
    {% end %}
  end
end
