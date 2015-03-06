require "spec"

describe "Int" do
  describe "**" do
    assert { (2 ** 2).should eq(4) }
    assert { (2 ** 2.5_f32).should eq(5.656854249492381) }
    assert { (2 ** 2.5).should eq(5.656854249492381) }
  end

  describe "divisible_by?" do
    assert { 10.divisible_by?(5).should be_true }
    assert { 10.divisible_by?(3).should be_false }
  end

  describe "even?" do
    assert { 2.even?.should be_true }
    assert { 3.even?.should be_false }
  end

  describe "odd?" do
    assert { 2.odd?.should be_false }
    assert { 3.odd?.should be_true }
  end

  describe "abs" do
    it "does for signed" do
      1_i8.abs.should eq(1_i8)
      -1_i8.abs.should eq(1_i8)
      1_i16.abs.should eq(1_i16)
      -1_i16.abs.should eq(1_i16)
      1_i32.abs.should eq(1_i32)
      -1_i32.abs.should eq(1_i32)
      1_i64.abs.should eq(1_i64)
      -1_i64.abs.should eq(1_i64)
    end

    it "does for unsigned" do
      1_u8.abs.should eq(1_u8)
      1_u16.abs.should eq(1_u16)
      1_u32.abs.should eq(1_u32)
      1_u64.abs.should eq(1_u64)
    end
  end

  describe "lcm" do
    assert { 2.lcm(2).should eq(2) }
    assert { 3.lcm(-7).should eq(21) }
    assert { 4.lcm(6).should eq(12) }
    assert { 0.lcm(2).should eq(0) }
    assert { 2.lcm(0).should eq(0) }
  end

  describe "to_s in base" do
    assert { 12.to_s(2).should eq("1100") }
    assert { -12.to_s(2).should eq("-1100") }
    assert { -123456.to_s(2).should eq("-11110001001000000") }
    assert { 1234.to_s(16).should eq("4D2") }
    assert { -1234.to_s(16).should eq("-4D2") }
    assert { 1234.to_s(36).should eq("YA") }
    assert { -1234.to_s(36).should eq("-YA") }
    assert { 0.to_s(16).should eq("0") }

    it "raises on base 1" do
      expect_raises { 123.to_s(1) }
    end

    it "raises on base 37" do
      expect_raises { 123.to_s(37) }
    end
  end

  describe "bit" do
    assert { 5.bit(0).should eq(1) }
    assert { 5.bit(1).should eq(0) }
    assert { 5.bit(2).should eq(1) }
    assert { 5.bit(3).should eq(0) }
  end

  describe "divmod" do
    assert { 5.divmod(3).should eq({1, 2}) }
  end

  describe "fdiv" do
    assert { 1.fdiv(1).should eq 1.0 }
    assert { 1.fdiv(2).should eq 0.5 }
    assert { 1.fdiv(0.5).should eq 2.0 }
    assert { 0.fdiv(1).should eq 0.0 }
    assert { 1.fdiv(0).should eq 1.0/0.0 }
  end

  describe "~" do
    assert { (~1).should eq(-2) }
    assert { (~1_u32).should eq(4294967294) }
  end

  describe "to" do
    it "does upwards" do
      a = 0
      1.to(3) { |i| a += i }
      a.should eq(6)
    end

    it "does downards" do
      a = 0
      4.to(2) { |i| a += i }
      a.should eq(9)
    end

    it "does when same" do
      a = 0
      2.to(2) { |i| a += i }
      a.should eq(2)
    end
  end

  describe "to_s" do
    it "does to_s for various int sizes" do
      127_i8.to_s.should eq("127")
      -128_i8.to_s.should eq("-128")

      32767_i16.to_s.should eq("32767")
      -32768_i16.to_s.should eq("-32768")

      2147483647.to_s.should eq("2147483647")
      -2147483648.to_s.should eq("-2147483648")

      9223372036854775807_i64.to_s.should eq("9223372036854775807")
      -9223372036854775808_i64.to_s.should eq("-9223372036854775808")

      255_u8.to_s.should eq("255")
      65535_u16.to_s.should eq("65535")
      4294967295_u32.to_s.should eq("4294967295")

      18446744073709551615_u64.to_s.should eq("18446744073709551615")
    end
  end

  describe "step" do
    it "steps through limit" do
      passed = false
      1.step(1) { |x| passed = true }
      fail "expected step to pass through 1" unless passed
    end
  end

  it "casts" do
    Int8.cast(1).should be_a(Int8)
    Int8.cast(1).should eq(1)

    Int16.cast(1).should be_a(Int16)
    Int16.cast(1).should eq(1)

    Int32.cast(1).should be_a(Int32)
    Int32.cast(1).should eq(1)

    Int64.cast(1).should be_a(Int64)
    Int64.cast(1).should eq(1)

    UInt8.cast(1).should be_a(UInt8)
    UInt8.cast(1).should eq(1)

    UInt16.cast(1).should be_a(UInt16)
    UInt16.cast(1).should eq(1)

    UInt32.cast(1).should be_a(UInt32)
    UInt32.cast(1).should eq(1)

    UInt64.cast(1).should be_a(UInt64)
    UInt64.cast(1).should eq(1)
  end

  it "raises when divides by zero" do
    expect_raises(DivisionByZero) { 1 / 0 }
    (4 / 2).should eq(2)
  end

  it "raises when mods by zero" do
    expect_raises(DivisionByZero) { 1 % 0 }
    (4 % 2).should eq(0)
  end
end
