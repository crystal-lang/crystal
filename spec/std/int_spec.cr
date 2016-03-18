require "spec"
require "big_int"

private def to_s_with_io(num)
  String.build { |str| num.to_s(str) }
end

private def to_s_with_io(num, base, upcase = false)
  String.build { |str| num.to_s(base, str, upcase) }
end

describe "Int" do
  describe "**" do
    assert { (2 ** 2).should be_close(4, 0.0001) }
    assert { (2 ** 2.5_f32).should be_close(5.656854249492381, 0.0001) }
    assert { (2 ** 2.5).should be_close(5.656854249492381, 0.0001) }
  end

  describe "#===(:Char)" do
    assert { (99 === 'c').should be_true }
    assert { (99_u8 === 'c').should be_true }
    assert { (99 === 'z').should be_false }
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
    assert { 0.to_s(62).should eq("0") }
    assert { 1.to_s(62).should eq("1") }
    assert { 10.to_s(62).should eq("a") }
    assert { 35.to_s(62).should eq("z") }
    assert { 36.to_s(62).should eq("A") }
    assert { 61.to_s(62).should eq("Z") }
    assert { 62.to_s(62).should eq("10") }
    assert { 97.to_s(62).should eq("1z") }
    assert { 3843.to_s(62).should eq("ZZ") }

    it "raises on base 1" do
      expect_raises { 123.to_s(1) }
    end

    it "raises on base 37" do
      expect_raises { 123.to_s(37) }
    end

    it "raises on base 62 with upcase" do
      expect_raises { 123.to_s(62, upcase: true) }
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
    assert { to_s_with_io(0, 62).should eq("0") }
    assert { to_s_with_io(1, 62).should eq("1") }
    assert { to_s_with_io(10, 62).should eq("a") }
    assert { to_s_with_io(35, 62).should eq("z") }
    assert { to_s_with_io(36, 62).should eq("A") }
    assert { to_s_with_io(61, 62).should eq("Z") }
    assert { to_s_with_io(62, 62).should eq("10") }
    assert { to_s_with_io(97, 62).should eq("1z") }
    assert { to_s_with_io(3843, 62).should eq("ZZ") }

    it "raises on base 1 with io" do
      expect_raises { to_s_with_io(123, 1) }
    end

    it "raises on base 37 with io" do
      expect_raises { to_s_with_io(123, 37) }
    end

    it "raises on base 62 with upcase with io" do
      expect_raises { to_s_with_io(12, 62, upcase: true) }
    end
  end

  describe "bit" do
    assert { 5.bit(0).should eq(1) }
    assert { 5.bit(1).should eq(0) }
    assert { 5.bit(2).should eq(1) }
    assert { 5.bit(3).should eq(0) }
    assert { 0.bit(63).should eq(0) }
    assert { Int64::MAX.bit(63).should eq(0) }
    assert { UInt64::MAX.bit(63).should eq(1) }
    assert { UInt64::MAX.bit(64).should eq(0) }
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
    Int8.new(1).should be_a(Int8)
    Int8.new(1).should eq(1)

    Int16.new(1).should be_a(Int16)
    Int16.new(1).should eq(1)

    Int32.new(1).should be_a(Int32)
    Int32.new(1).should eq(1)

    Int64.new(1).should be_a(Int64)
    Int64.new(1).should eq(1)

    UInt8.new(1).should be_a(UInt8)
    UInt8.new(1).should eq(1)

    UInt16.new(1).should be_a(UInt16)
    UInt16.new(1).should eq(1)

    UInt32.new(1).should be_a(UInt32)
    UInt32.new(1).should eq(1)

    UInt64.new(1).should be_a(UInt64)
    UInt64.new(1).should eq(1)
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

  describe "#popcount" do
    assert { 5_i8.popcount.should eq(2) }
    assert { 127_i8.popcount.should eq(7) }
    assert { -1_i8.popcount.should eq(8) }
    assert { -128_i8.popcount.should eq(1) }

    assert { 0_u8.popcount.should eq(0) }
    assert { 255_u8.popcount.should eq(8) }

    assert { 5_i16.popcount.should eq(2) }
    assert { -6_i16.popcount.should eq(14) }
    assert { 65535_u16.popcount.should eq(16) }

    assert { 0_i32.popcount.should eq(0) }
    assert { 2147483647_i32.popcount.should eq(31) }
    assert { 4294967295_u32.popcount.should eq(32) }

    assert { 5_i64.popcount.should eq(2) }
    assert { 9223372036854775807_i64.popcount.should eq(63) }
    assert { 18446744073709551615_u64.popcount.should eq(64) }
  end

  it "compares signed vs. unsigned integers" do
    signed_ints = [Int8::MAX, Int16::MAX, Int32::MAX, Int64::MAX, Int8::MIN, Int16::MIN, Int32::MIN, Int64::MIN, 0_i8, 0_i16, 0_i32, 0_i64]
    unsigned_ints = [UInt8::MAX, UInt16::MAX, UInt32::MAX, UInt64::MAX, 0_u8, 0_u16, 0_u32, 0_u64]

    big_signed_ints = signed_ints.map &.to_big_i
    big_unsigned_ints = unsigned_ints.map &.to_big_i

    signed_ints.zip(big_signed_ints) do |si, bsi|
      unsigned_ints.zip(big_unsigned_ints) do |ui, bui|
        {% for op in %w(< <= > >=).map(&.id) %}
          if (si {{op}} ui) != (bsi {{op}} bui)
            fail "comparison of #{si} {{op}} #{ui} (#{si.class} {{op}} #{ui.class}) gave incorrect result"
          end
        {% end %}
      end
    end
  end
end
