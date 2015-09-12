require "spec"

private def to_s_with_io(num)
  String.build { |str| num.to_s(str) }
end

private def to_s_with_io(num, base, upcase = false)
  String.build { |str| num.to_s(base, str, upcase) }
end

describe "Int" do
  describe "**" do
    assert { (2 ** 2).should eq(4) }
    assert { (2 ** 2.5_f32).should eq(5.656854249492381) }
    assert { (2 ** 2.5).should eq(5.656854249492381) }
  end

  describe "#===(:Char)" do
    assert { (99 === 'c').should     be_true }
    assert { (99_u8 === 'c').should  be_true }
    assert { (99 === 'z').should     be_false }
    assert { (37202 === '酒').should be_true }
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

  describe "succ" do
    assert { 8.succ.should eq(9) }
    assert { -2147483648.succ.should eq(-2147483647) }
    assert { 2147483646.succ.should eq(2147483647) }
  end

  describe "pred" do
    assert { 9.pred.should eq(8) }
    assert { -2147483647.pred.should eq(-2147483648) }
    assert { 2147483647.pred.should eq(2147483646) }
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
    assert { 1234.to_s(16).should eq("4d2") }
    assert { -1234.to_s(16).should eq("-4d2") }
    assert { 1234.to_s(36).should eq("ya") }
    assert { -1234.to_s(36).should eq("-ya") }
    assert { 1234.to_s(16, upcase: true).should eq("4D2") }
    assert { -1234.to_s(16, upcase: true).should eq("-4D2") }
    assert { 1234.to_s(36, upcase: true).should eq("YA") }
    assert { -1234.to_s(36, upcase: true).should eq("-YA") }
    assert { 0.to_s(2).should eq("0") }
    assert { 0.to_s(16).should eq("0") }
    assert { 1.to_s(2).should eq("1") }
    assert { 1.to_s(16).should eq("1") }

    it "raises on base 1" do
      expect_raises { 123.to_s(1) }
    end

    it "raises on base 37" do
      expect_raises { 123.to_s(37) }
    end

    assert { to_s_with_io(12, 2).should eq("1100") }
    assert { to_s_with_io(-12, 2).should eq("-1100") }
    assert { to_s_with_io(-123456, 2).should eq("-11110001001000000") }
    assert { to_s_with_io(1234, 16).should eq("4d2") }
    assert { to_s_with_io(-1234, 16).should eq("-4d2") }
    assert { to_s_with_io(1234, 36).should eq("ya") }
    assert { to_s_with_io(-1234, 36).should eq("-ya") }
    assert { to_s_with_io(1234, 16, upcase: true).should eq("4D2") }
    assert { to_s_with_io(-1234, 16, upcase: true).should eq("-4D2") }
    assert { to_s_with_io(1234, 36, upcase: true).should eq("YA") }
    assert { to_s_with_io(-1234, 36, upcase: true).should eq("-YA") }
    assert { to_s_with_io(0, 2).should eq("0") }
    assert { to_s_with_io(0, 16).should eq("0") }
    assert { to_s_with_io(1, 2).should eq("1") }
    assert { to_s_with_io(1, 16).should eq("1") }

    it "raises on base 1 with io" do
      expect_raises { to_s_with_io(123, 1) }
    end

    it "raises on base 37 with io" do
      expect_raises { to_s_with_io(123, 37) }
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

  describe ">>" do
    assert { (8000 >> 1).should eq(4000) }
    assert { (8000 >> 2).should eq(2000) }
    assert { (8000 >> 32).should eq(0) }
    assert { (8000 >> -1).should eq(16000) }
  end

  describe "<<" do
    assert { (8000 << 1).should eq(16000) }
    assert { (8000 << 2).should eq(32000) }
    assert { (8000 << 32).should eq(0) }
    assert { (8000 << -1).should eq(4000) }
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
      0.to_s.should eq("0")
      1.to_s.should eq("1")

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

    it "does to_s for various int sizes with IO" do
      to_s_with_io(0).should eq("0")
      to_s_with_io(1).should eq("1")

      to_s_with_io(127_i8).should eq("127")
      to_s_with_io(-128_i8).should eq("-128")

      to_s_with_io(32767_i16).should eq("32767")
      to_s_with_io(-32768_i16).should eq("-32768")

      to_s_with_io(2147483647).should eq("2147483647")
      to_s_with_io(-2147483648).should eq("-2147483648")

      to_s_with_io(9223372036854775807_i64).should eq("9223372036854775807")
      to_s_with_io(-9223372036854775808_i64).should eq("-9223372036854775808")

      to_s_with_io(255_u8).should eq("255")
      to_s_with_io(65535_u16).should eq("65535")
      to_s_with_io(4294967295_u32).should eq("4294967295")

      to_s_with_io(18446744073709551615_u64).should eq("18446744073709551615")
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

  it "gets times iterator" do
    iter = 3.times
    iter.next.should eq(0)
    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(0)
  end

  it "does %" do
    (7 % 5).should eq(2)
    (-7 % 5).should eq(3)

    (13 % -4).should eq(-3)
    (-13 % -4).should eq(-1)
  end

  it "does remainder" do
    7.remainder(5).should eq(2)
    -7.remainder(5).should eq(-2)

    13.remainder(-4).should eq(1)
    -13.remainder(-4).should eq(-1)
  end

  it "gets upto iterator" do
    iter = 1.upto(3)
    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should eq(3)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(1)
  end

  it "gets downto iterator" do
    iter = 3.downto(1)
    iter.next.should eq(3)
    iter.next.should eq(2)
    iter.next.should eq(1)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(3)
  end

  it "gets to iterator" do
    iter = 1.to(3)
    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should eq(3)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(1)
  end
end
