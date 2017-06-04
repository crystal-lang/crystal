# The example numbers in these specs are ported from the C++
# "double-conversions" library. The following is their license:
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
require "spec"

private alias DiyFP = Float::Printer::DiyFP

describe DiyFP do
  it "multiply" do
    fp1 = DiyFP.new(3_u64, 0)
    fp2 = DiyFP.new(2_u64, 0)
    prod = fp1 * fp2

    prod.frac.should eq 0
    prod.exp.should eq 64
  end

  it "multiply" do
    fp1 = DiyFP.new(0x8000000000000000, 11)
    fp2 = DiyFP.new(2_u64, 13)
    prod = fp1 * fp2

    prod.frac.should eq 1
    prod.exp.should eq 11 + 13 + 64
  end

  it "multiply rounding" do
    fp1 = DiyFP.new(0x8000000000000001_u64, 11)
    fp2 = DiyFP.new(1_u64, 13)
    prod = fp1 * fp2

    prod.frac.should eq 1
    prod.exp.should eq 11 + 13 + 64
  end

  it "multiply rounding" do
    fp1 = DiyFP.new(0x7fffffffffffffff_u64, 11)
    fp2 = DiyFP.new(1_u64, 13)
    prod = fp1 * fp2

    prod.frac.should eq 0
    prod.exp.should eq 11 + 13 + 64
  end

  it "multiply big numbers" do
    fp1 = DiyFP.new(0xffffffffffffffff_u64, 11)
    fp2 = DiyFP.new(0xffffffffffffffff_u64, 13)
    prod = fp1 * fp2

    prod.frac.should eq 0xfffffffffffffffe_u64
    prod.exp.should eq 11 + 13 + 64
  end

  it "converts ordered 64" do
    ordered = 0x0123456789ABCDEF_u64
    f = ordered.unsafe_as(Float64)
    f.should eq 3512700564088504e-318 # ensure byte order

    fp = DiyFP.from_f(f)

    fp.exp.should eq 0x12 - 0x3FF - 52
    # The 52 mantissa bits, plus the implicit 1 in bit 52 as a UINT64.
    fp.frac.should eq 0x0013456789ABCDEF
  end

  it "converts ordered 32" do
    ordered = 0x01234567_u32
    f = ordered.unsafe_as(Float32)
    f.should eq(2.9988165487136453e-38_f32)

    fp = DiyFP.from_f(f)

    fp.exp.should eq 0x2 - 0x7F - 23
    # The 23 mantissa bits, plus the implicit 1 in bit 24 as a uint32.

    fp.frac.should eq 0xA34567
  end

  it "converts min f64" do
    min = 0x0000000000000001_u64
    f = min.unsafe_as(Float64)
    f.should eq 5e-324 # ensure byte order

    fp = DiyFP.from_f(f)

    fp.exp.should eq -0x3FF - 52 + 1
    # This is denormal, so no hidden bit
    fp.frac.should eq 1
  end

  it "converts min f32" do
    min = 0x00000001_u32
    f = min.unsafe_as(Float32)
    fp = DiyFP.from_f(f)

    fp.exp.should eq -0x7F - 23 + 1
    # This is a denormal; so no hidden bit.
    fp.frac.should eq 1
  end

  it "converts max f64" do
    max = 0x7fefffffffffffff_u64
    f = max.unsafe_as(Float64)
    f.should eq 1.7976931348623157e308 # ensure byte order

    fp = DiyFP.from_f(f)

    fp.exp.should eq 0x7FE - 0x3FF - 52
    fp.frac.should eq 0x001fffffffffffff_u64
  end

  it "converts max f32" do
    max = 0x7f7fffff_u64
    f = max.unsafe_as(Float32)
    f.should eq 3.4028234e38_f32 # ensure byte order

    fp = DiyFP.from_f(f)

    fp.exp.should eq 0xFE - 0x7F - 23
    fp.frac.should eq 0x00ffffff_u64
  end

  it "normalizes ordered" do
    ordered = 0x0123456789ABCDEF_u64
    f = ordered.unsafe_as(Float64)

    fp = DiyFP.from_f_normalized(f)

    fp.exp.should eq 0x12 - 0x3FF - 52 - 11
    fp.frac.should eq 0x0013456789ABCDEF_u64 << 11
  end

  it "normalizes min f64" do
    min = 0x0000000000000001_u64
    f = min.unsafe_as(Float64)

    fp = DiyFP.from_f_normalized(f)

    fp.exp.should eq -0x3FF - 52 + 1 - 63
    # This is a denormal; so no hidden bit
    fp.frac.should eq 0x8000000000000000
  end

  it "normalizes max f64" do
    max = 0x7fefffffffffffff_u64
    f = max.unsafe_as(Float64)

    fp = DiyFP.from_f_normalized(f)

    fp.exp.should eq 0x7FE - 0x3FF - 52 - 11
    fp.frac.should eq 0x001fffffffffffff << 11
  end
end
