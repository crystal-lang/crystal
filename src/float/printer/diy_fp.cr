# DiyFP is ported from the C++ "double-conversions" library.
# The following is their license:
#   Copyright 2010 the V8 project authors. All rights reserved.
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

require "./ieee"

# This "Do It Yourself Floating Point" struct implements a floating-point number
# with a `UIht64` significand and an `Int32` exponent. Normalized DiyFP numbers will
# have the most significant bit of the significand set.
# Multiplication and Subtraction do not normalize their results.
# DiyFP is not designed to contain special Floats (NaN and Infinity).
struct Float::Printer::DiyFP
  SIGNIFICAND_SIZE = 64
  # Also known as the significand
  property frac : UInt64
  # exponent
  property exp : Int32

  def initialize(@frac, @exp)
  end

  def initialize(@frac, exp : Int16)
    @exp = exp.to_i32
  end

  def new(frac : Int32, exp)
    new frac.to_u64, exp
  end

  # Returns a new `DiyFP` caculated as self - *other*.
  #
  # The exponents of both numbers must be the same and the frac of self must be
  # greater than the other.
  #
  # This result is not normalized.
  def -(other : DiyFP)
    _invariant self.exp == other.exp && frac >= other.frac
    self.class.new(frac - other.frac, exp)
  end

  MASK32 = 0xFFFFFFFF_u32

  # Returns a new `DiyFP` caculated as self * *other*.
  #
  # Simply "emulates" a 128 bit multiplication.
  # However: the resulting number only contains 64 bits. The least
  # significant 64 bits are only used for rounding the most significant 64
  # bits.
  #
  # This result is not normalized.
  def *(other : DiyFP)
    a = frac >> 32
    b = frac & MASK32
    c = other.frac >> 32
    d = other.frac & MASK32
    ac = a*c
    bc = b*c
    ad = a*d
    bd = b*d
    tmp = (bd >> 32) + (ad & MASK32) + (bc & MASK32)
    # By adding 1U << 31 to tmp we round the final result.
    # Halfway cases will be round up.
    tmp += 1_u32 << 31
    f = ac + (ad >> 32) + (bc >> 32) + (tmp >> 32)
    e = exp + other.exp + 64

    self.class.new(f, e)
  end

  def normalize
    _invariant frac != 0
    f = frac
    e = exp

    # This method is mainly called for normalizing boundaries. In general
    # boundaries need to be shifted by 10 bits. We thus optimize for this case.
    k10MSBits = 0xFFC0000000000000_u64
    kUint64MSB = 0x8000000000000000_u64
    while (f & k10MSBits) == 0
      # puts "  sig: #{f}"
      #  puts "  exp: #{e}"
      f <<= 10_u64
      e -= 10
    end
    while (f & kUint64MSB) == 0
      # puts "  sig: #{f}"
      # puts "  exp: #{e}"
      f <<= 1_u64
      e -= 1
    end
    DiyFP.new(f, e)
  end

  def self.from_f(d : Float64 | Float32)
    _invariant d > 0
    frac, exp = IEEE.frac_and_exp(d)
    new(frac, exp)
  end

  # Normalize such that the most signficiant bit of frac is set
  def self.from_f_normalized(v : Float64 | Float32)
    pre_normalized = from_f(v)
    f = pre_normalized.frac
    e = pre_normalized.exp

    # could be a denormal
    while (f & IEEE::HIDDEN_BIT_64) == 0
      f <<= 1
      e -= 1
    end

    # do the final shifts in one go
    f <<= DiyFP::SIGNIFICAND_SIZE - IEEE::SIGNIFICAND_SIZE_64
    e -= DiyFP::SIGNIFICAND_SIZE - IEEE::SIGNIFICAND_SIZE_64
    DiyFP.new(f, e)
  end

  private macro _invariant(exp, file = __FILE__, line = __LINE__)
    {% if !flag?(:release) %}
      unless {{exp}}
        raise "Assertion Failed #{{{file}}}:#{{{line}}}"
      end
    {% end %}
  end
end
