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

private def gen_bound(v : UInt64)
  f = v.unsafe_as(Float64)
  gen_bound(f)
end

private def gen_bound(v : UInt32)
  f = v.unsafe_as(Float32)
  gen_bound(f)
end

private def gen_bound(v : Float64 | Float32)
  fp = Float::Printer::DiyFP.from_f_normalized(v)
  b = Float::Printer::IEEE.normalized_boundaries(v)
  b[:minus].exp.should eq fp.exp
  b[:plus].exp.should eq fp.exp

  return fp.frac, b[:minus].frac, b[:plus].frac
end

describe "Float64 boundaires" do
  it "boundaries 1.5" do
    fp, mi, pl = gen_bound(1.5)
    # 1.5 does not have a significand of the form 2^p (for some p).
    # Therefore its boundaries are at the same distance.
    (pl - fp).should eq(fp - mi)
    (fp - mi).should eq(1 << 10)
  end

  it "boundaries 1.0" do
    fp, mi, pl = gen_bound(1.0)
    # 1.0 does have a significand of the form 2^p (for some p).
    # Therefore its lower boundary is twice as close as the upper boundary.
    (pl - fp).should be > fp - mi
    (fp - mi).should eq 1 << 9
    (pl - fp).should eq 1 << 10
  end

  it "boundaries min float64" do
    fp, mi, pl = gen_bound(0x0000000000000001_u64)
    # min-value does not have a significand of the form 2^p (for some p).
    # Therefore its boundaries are at the same distance.
    (pl - fp).should eq fp - mi
    (fp - mi).should eq 1_u64 << 62
  end

  it "boundaries min normal f64" do
    fp, mi, pl = gen_bound(0x0010000000000000_u64)
    # Even though the significand is of the form 2^p (for some p), its boundaries
    # are at the same distance. (This is the only exception).
    (fp - mi).should eq(pl - fp)
    (fp - mi).should eq(1 << 10)
  end

  it "boundaries max denormal f64" do
    fp, mi, pl = gen_bound(0x000FFFFFFFFFFFFF_u64)

    (fp - mi).should eq(pl - fp)
    (fp - mi).should eq(1 << 11)
  end

  it "boundaries max f64" do
    fp, mi, pl = gen_bound(0x7fEFFFFFFFFFFFFF_u64)
    # max-value does not have a significand of the form 2^p (for some p).
    # Therefore its boundaries are at the same distance.
    (fp - mi).should eq(pl - fp)
    (fp - mi).should eq(1 << 10)
  end
end

describe "Float32 boundaires" do
  it "boundaries 1.5" do
    fp, mi, pl = gen_bound(1.5_f32)
    # 1.5 does not have a significand of the form 2^p (for some p).
    # Therefore its boundaries are at the same distance.
    (pl - fp).should eq(fp - mi)
    # Normalization shifts the significand by 8 bits. Add 32 bits for the bigger
    # data-type, and remove 1 because boundaries are at half a ULP.
    (fp - mi).should eq(1_u64 << 39)
  end

  it "boundaries 1.0" do
    fp, mi, pl = gen_bound(1.0_f32)
    # 1.0 does have a significand of the form 2^p (for some p).
    # Therefore its lower boundary is twice as close as the upper boundary.
    (pl - fp).should be > fp - mi
    (fp - mi).should eq(1_u64 << 38)
    (pl - fp).should eq(1_u64 << 39)
  end

  it "min Float32" do
    fp, mi, pl = gen_bound(0x00000001_u32)
    #  min-value does not have a significand of the form 2^p (for some p).
    # Therefore its boundaries are at the same distance.
    (pl - fp).should eq(fp - mi)
    # Denormals have their boundaries much closer.
    (fp - mi).should eq(1_u64 << 62)
  end

  it "smallest normal 32" do
    fp, mi, pl = gen_bound(0x00800000_u32)
    # Even though the significand is of the form 2^p (for some p), its boundaries
    # are at the same distance. (This is the only exception).
    (pl - fp).should eq(fp - mi)
    (fp - mi).should eq(1_u64 << 39)
  end

  it "largest denormal 32" do
    fp, mi, pl = gen_bound(0x007FFFFF_u32)
    (pl - fp).should eq(fp - mi)
    (fp - mi).should eq(1_u64 << 40)
  end

  it "max Float32" do
    fp, mi, pl = gen_bound(0x7F7FFFFF_u32)
    # max-value does not have a significand of the form 2^p (for some p).
    # Therefore its boundaries are at the same distance.
    (pl - fp).should eq(fp - mi)
    (fp - mi).should eq(1_u64 << 39)
  end
end
