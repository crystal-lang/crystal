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

module FloatPrinter::IEEE
  extend self

  EXPONENT_MASK             = 0x7FF0000000000000_u64
  SIGNIFICAND_MASK          = 0x000FFFFFFFFFFFFF_u64
  HIDDEN_BIT                = 0x0010000000000000_u64 # hiden bit
  PHYSICAL_SIGNIFICAND_SIZE =                     52 # Excludes the hidden bit
  SIGNIFICAND_SIZE          =                     53 # float64
  EXPONENT_BIAS             = 0x3FF + PHYSICAL_SIGNIFICAND_SIZE
  DENORMAL_EXPONENT         = -EXPONENT_BIAS + 1
  SIGN_MASK                 = 0x8000000000000000_u64

  def to_d64(v : Float64)
    d64 = (pointerof(v).as UInt64*).value
  end

  def sign(d64 : UInt64)
    (d64 & SIGN_MASK) == 0 ? 1 : -1
  end

  def special?(d64 : UInt64)
    (d64 & EXPONENT_MASK) == EXPONENT_MASK
  end

  def inf?(d64 : UInt64)
    special?(d64) && (d64 & SIGNIFICAND_MASK == 0)
  end

  def nan?(d64 : UInt64)
    special?(d64) && (d64 & SIGNIFICAND_MASK != 0)
  end

  # Computes the two boundaries of v.
  # The bigger boundary (m_plus) is normalized. The lower boundary has the same
  # exponent as m_plus.
  # Precondition: the value encoded by this Double must be greater than 0.
  def normalized_boundaries(v : Float64)
    _invariant v > 0
    w = DiyFP.from_f64(v)
    # pp w
    # p "inner: #{DiyFP.new((w.frac << 1) + 1, w.exp - 1).inspect}"
    m_plus = DiyFP.new((w.frac << 1) + 1, w.exp - 1).normalize
    # pp m_plus

    d64 = to_d64(v)

    # The boundary is closer if the significand is of the form f == 2^p-1 then
    # the lower boundary is closer.
    # Think of v = 1000e10 and v- = 9999e9.
    # Then the boundary (== (v - v-)/2) is not just at a distance of 1e9 but
    # at a distance of 1e8.
    # The only exception is for the smallest normal: the largest denormal is
    # at the same distance as its successor.
    # Note: denormals have the same exponent as the smallest normals.
    physical_significand_is_zero = (d64 & SIGNIFICAND_MASK) == 0
    # pp physical_significand_is_zero

    lower_bound_closer = physical_significand_is_zero && (exponent(d64) != DENORMAL_EXPONENT)
    calcualted_exp = exponent(d64)
    # pp calcualted_exp
    calc_denormal = denormal?(d64)
    # pp calc_denormal
    # pp lower_bound_closer
    # pp w
    f, e = if lower_bound_closer
             {(w.frac << 2) - 1, w.exp - 2}
           else
             {(w.frac << 1) - 1, w.exp - 1}
           end
    # pp ["pre", f,e]
    m_minus = DiyFP.new(f << (e - m_plus.exp), m_plus.exp)
    # pp m_minus
    return {minus: m_minus, plus: m_plus}
  end

  def frac_and_exp(v : Float64)
    d64 = to_d64(v)
    _invariant (d64 & EXPONENT_MASK) != EXPONENT_MASK

    if (d64 & EXPONENT_MASK) == 0 # denormal float
      frac = d64 & SIGNIFICAND_MASK
      exp = 1 - EXPONENT_BIAS
    else
      frac = (d64 & SIGNIFICAND_MASK) + HIDDEN_BIT
      exp = (((d64 & EXPONENT_MASK) >> PHYSICAL_SIGNIFICAND_SIZE) - EXPONENT_BIAS).to_i
    end

    {frac, exp}
  end

  private def denormal?(d64 : UInt64) : Bool
    (d64 & EXPONENT_MASK) == 0
  end

  private def exponent(d64 : UInt64)
    # pp (denormal?(d64))
    return DENORMAL_EXPONENT if denormal?(d64)
    baised_e = ((d64 & EXPONENT_MASK) >> PHYSICAL_SIGNIFICAND_SIZE).to_i
    # puts [(d64 & EXPONENT_MASK).to_i, PHYSICAL_SIGNIFICAND_SIZE]
    # pp [baised_e, EXPONENT_BIAS]
    baised_e - EXPONENT_BIAS
  end

  private macro _invariant(exp, file = __FILE__, line = __LINE__)
    {% if !flag?(:release) %}
      unless {{exp}}
        raise "Assertion Failed #{{{file}}}:#{{{line}}}"
      end
    {% end %}
  end
end
