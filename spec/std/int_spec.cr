require "spec"

describe "Int" do
  describe "**" do
    assert { expect((2 ** 2)).to eq(4) }
    assert { expect((2 ** 2.5_f32)).to eq(5.656854249492381) }
    assert { expect((2 ** 2.5)).to eq(5.656854249492381) }
  end

  describe "divisible_by?" do
    assert { expect(10.divisible_by?(5)).to be_true }
    assert { expect(10.divisible_by?(3)).to be_false }
  end

  describe "even?" do
    assert { expect(2.even?).to be_true }
    assert { expect(3.even?).to be_false }
  end

  describe "odd?" do
    assert { expect(2.odd?).to be_false }
    assert { expect(3.odd?).to be_true }
  end

  describe "abs" do
    it "does for signed" do
      expect(1_i8.abs).to eq(1_i8)
      expect(-1_i8.abs).to eq(1_i8)
      expect(1_i16.abs).to eq(1_i16)
      expect(-1_i16.abs).to eq(1_i16)
      expect(1_i32.abs).to eq(1_i32)
      expect(-1_i32.abs).to eq(1_i32)
      expect(1_i64.abs).to eq(1_i64)
      expect(-1_i64.abs).to eq(1_i64)
    end

    it "does for unsigned" do
      expect(1_u8.abs).to eq(1_u8)
      expect(1_u16.abs).to eq(1_u16)
      expect(1_u32.abs).to eq(1_u32)
      expect(1_u64.abs).to eq(1_u64)
    end
  end

  describe "lcm" do
    assert { expect(2.lcm(2)).to eq(2) }
    assert { expect(3.lcm(-7)).to eq(21) }
    assert { expect(4.lcm(6)).to eq(12) }
    assert { expect(0.lcm(2)).to eq(0) }
    assert { expect(2.lcm(0)).to eq(0) }
  end

  describe "to_s in base" do
    assert { expect(12.to_s(2)).to eq("1100") }
    assert { expect(-12.to_s(2)).to eq("-1100") }
    assert { expect(-123456.to_s(2)).to eq("-11110001001000000") }
    assert { expect(1234.to_s(16)).to eq("4D2") }
    assert { expect(-1234.to_s(16)).to eq("-4D2") }
    assert { expect(1234.to_s(36)).to eq("YA") }
    assert { expect(-1234.to_s(36)).to eq("-YA") }
    assert { expect(0.to_s(16)).to eq("0") }

    it "raises on base 1" do
      expect_raises { 123.to_s(1) }
    end

    it "raises on base 37" do
      expect_raises { 123.to_s(37) }
    end
  end

  describe "bit" do
    assert { expect(5.bit(0)).to eq(1) }
    assert { expect(5.bit(1)).to eq(0) }
    assert { expect(5.bit(2)).to eq(1) }
    assert { expect(5.bit(3)).to eq(0) }
  end

  describe "divmod" do
    assert { expect(5.divmod(3)).to eq({1, 2}) }
  end

  describe "fdiv" do
    assert { expect(1.fdiv(1)).to eq 1.0 }
    assert { expect(1.fdiv(2)).to eq 0.5 }
    assert { expect(1.fdiv(0.5)).to eq 2.0 }
    assert { expect(0.fdiv(1)).to eq 0.0 }
    assert { expect(1.fdiv(0)).to eq 1.0/0.0 }
  end

  describe "~" do
    assert { expect((~1)).to eq(-2) }
    assert { expect((~1_u32)).to eq(4294967294) }
  end

  describe "to" do
    it "does upwards" do
      a = 0
      1.to(3) { |i| a += i }
      expect(a).to eq(6)
    end

    it "does downards" do
      a = 0
      4.to(2) { |i| a += i }
      expect(a).to eq(9)
    end

    it "does when same" do
      a = 0
      2.to(2) { |i| a += i }
      expect(a).to eq(2)
    end
  end

  describe "to_s" do
    it "does to_s for various int sizes" do
      expect(127_i8.to_s).to eq("127")
      expect(-128_i8.to_s).to eq("-128")

      expect(32767_i16.to_s).to eq("32767")
      expect(-32768_i16.to_s).to eq("-32768")

      expect(2147483647.to_s).to eq("2147483647")
      expect(-2147483648.to_s).to eq("-2147483648")

      expect(9223372036854775807_i64.to_s).to eq("9223372036854775807")
      expect(-9223372036854775808_i64.to_s).to eq("-9223372036854775808")

      expect(255_u8.to_s).to eq("255")
      expect(65535_u16.to_s).to eq("65535")
      expect(4294967295_u32.to_s).to eq("4294967295")

      expect(18446744073709551615_u64.to_s).to eq("18446744073709551615")
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
    expect(Int8.cast(1)).to be_a(Int8)
    expect(Int8.cast(1)).to eq(1)

    expect(Int16.cast(1)).to be_a(Int16)
    expect(Int16.cast(1)).to eq(1)

    expect(Int32.cast(1)).to be_a(Int32)
    expect(Int32.cast(1)).to eq(1)

    expect(Int64.cast(1)).to be_a(Int64)
    expect(Int64.cast(1)).to eq(1)

    expect(UInt8.cast(1)).to be_a(UInt8)
    expect(UInt8.cast(1)).to eq(1)

    expect(UInt16.cast(1)).to be_a(UInt16)
    expect(UInt16.cast(1)).to eq(1)

    expect(UInt32.cast(1)).to be_a(UInt32)
    expect(UInt32.cast(1)).to eq(1)

    expect(UInt64.cast(1)).to be_a(UInt64)
    expect(UInt64.cast(1)).to eq(1)
  end

  it "raises when divides by zero" do
    expect_raises(DivisionByZero) { 1 / 0 }
    expect((4 / 2)).to eq(2)
  end

  it "raises when mods by zero" do
    expect_raises(DivisionByZero) { 1 % 0 }
    expect((4 % 2)).to eq(0)
  end
end
