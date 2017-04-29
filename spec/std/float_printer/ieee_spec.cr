require "spec"
require "float_printer/diy_fp"
require "float_printer/ieee"
include FloatPrinter

private def gen_bound(v : UInt64)
  f = pointerof(v).as(Float64*).value
  gen_bound(f)
end

private def gen_bound(v : UInt32)
  f = pointerof(v).as(Float32*).value
  gen_bound(f)
end

private def gen_bound(v : Float64 | Float32)
  fp = DiyFP.from_f_normalized(v)
  b = IEEE.normalized_boundaries(v)
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
