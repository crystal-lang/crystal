require "spec"
require "big_int"

describe "BigInt" do
  it "creates with a value of zero" do
    expect(BigInt.new.to_s).to eq("0")
  end

  it "creates from signed ints" do
    expect(BigInt.new(-1_i8).to_s).to eq("-1")
    expect(BigInt.new(-1_i16).to_s).to eq("-1")
    expect(BigInt.new(-1_i32).to_s).to eq("-1")
    expect(BigInt.new(-1_i64).to_s).to eq("-1")
  end

  it "creates from unsigned ints" do
    expect(BigInt.new(1_u8).to_s).to eq("1")
    expect(BigInt.new(1_u16).to_s).to eq("1")
    expect(BigInt.new(1_u32).to_s).to eq("1")
    expect(BigInt.new(1_u64).to_s).to eq("1")
  end

  it "creates from string" do
    expect(BigInt.new("12345678").to_s).to eq("12345678")
  end

  it "compares" do
    expect(1.to_big_i).to eq(1.to_big_i)
    expect(1.to_big_i).to eq(1)
    expect(1.to_big_i).to eq(1_u8)

    expect([3.to_big_i, 2.to_big_i, 10.to_big_i, 4, 8_u8].sort).to eq([2, 3, 4, 8, 10])
  end

  it "adds" do
    expect((1.to_big_i + 2.to_big_i)).to eq(3.to_big_i)
    expect((1.to_big_i + 2)).to eq(3.to_big_i)
    expect((1.to_big_i + 2_u8)).to eq(3.to_big_i)
    expect((5.to_big_i + (-2_i64))).to eq(3.to_big_i)

    expect((2 + 1.to_big_i)).to eq(3.to_big_i)
  end

  it "subs" do
    expect((5.to_big_i - 2.to_big_i)).to eq(3.to_big_i)
    expect((5.to_big_i - 2)).to eq(3.to_big_i)
    expect((5.to_big_i - 2_u8)).to eq(3.to_big_i)
    expect((5.to_big_i - (-2_i64))).to eq(7.to_big_i)

    expect((5 - 1.to_big_i)).to eq(4.to_big_i)
    expect((-5 - 1.to_big_i)).to eq(-6.to_big_i)
  end

  it "negates" do
    expect((-(-123.to_big_i))).to eq(123.to_big_i)
  end

  it "multiplies" do
    expect((2.to_big_i * 3.to_big_i)).to eq(6.to_big_i)
    expect((2.to_big_i * 3)).to eq(6.to_big_i)
    expect((2.to_big_i * 3_u8)).to eq(6.to_big_i)
    expect((3 * 2.to_big_i)).to eq(6.to_big_i)
    expect((3_u8 * 2.to_big_i)).to eq(6.to_big_i)
  end

  it "gets absolute value" do
    expect((-10.to_big_i.abs)).to eq(10.to_big_i)
  end

  it "divides" do
    expect((10.to_big_i / 3.to_big_i)).to eq(3.to_big_i)
    expect((10.to_big_i / 3)).to eq(3.to_big_i)
    expect((10.to_big_i / -3)).to eq(-3.to_big_i)
    expect((10 / 3.to_big_i)).to eq(3.to_big_i)
  end

  it "does modulo" do
    expect((10.to_big_i % 3.to_big_i)).to eq(1.to_big_i)
    expect((10.to_big_i % 3)).to eq(1.to_big_i)
    expect((10.to_big_i % -3)).to eq(1.to_big_i)
    expect((10 % 3.to_big_i)).to eq(1.to_big_i)
  end

  it "does bitwise and" do
    expect((123.to_big_i & 321)).to eq(65)
    expect((BigInt.new("96238761238973286532") & 86325735648)).to eq(69124358272)
  end

  it "does bitwise or" do
    expect((123.to_big_i | 4)).to eq(127)
    expect((BigInt.new("96238761238986532") | 8632573)).to eq(96238761247506429)
  end

  it "does bitwise xor" do
    expect((123.to_big_i ^ 50)).to eq(73)
    expect((BigInt.new("96238761238986532") ^ 8632573)).to eq(96238761247393753)
  end

  it "does bitwise not" do
    expect((~123)).to eq(-124)

    a = BigInt.new("192623876123689865327")
    b = BigInt.new("-192623876123689865328")
    expect((~a)).to eq(b)
  end

  it "does bitwise right shift" do
    expect((123.to_big_i >> 4)).to eq(7)
    expect((123456.to_big_i >> 8)).to eq(482)
  end

  it "does bitwise left shift" do
    expect((123.to_big_i << 4)).to eq(1968)
    expect((123456.to_big_i << 8)).to eq(31604736)
  end

  it "raises if divides by zero" do
    expect_raises DivisionByZero do
      10.to_big_i / 0.to_big_i
    end

    expect_raises DivisionByZero do
      10.to_big_i / 0
    end

    expect_raises DivisionByZero do
      10 / 0.to_big_i
    end
  end

  it "raises if mods by zero" do
    expect_raises DivisionByZero do
      10.to_big_i % 0.to_big_i
    end

    expect_raises DivisionByZero do
      10.to_big_i % 0
    end

    expect_raises DivisionByZero do
      10 % 0.to_big_i
    end
  end

  it "does to_s in the given base" do
    a = BigInt.new("1234567890123456789")
    b = "1000100100010000100001111010001111101111010011000000100010101"
    c = "112210f47de98115"
    d = "128gguhuuj08l"
    expect(a.to_s(2)).to eq(b)
    expect(a.to_s(16)).to eq(c)
    expect(a.to_s(32)).to eq(d)
  end

  it "casts other ints and strings" do
    a = BigInt.new(123456)
    b = BigInt.cast(123456)
    expect(a).to eq(b)

    a = BigInt.new("123456789012345678901234567890")
    b = BigInt.cast("123456789012345678901234567890")
    expect(a).to eq(b)
  end

  it "can use Number::[]" do
    a = BigInt[146, "3464", 97, "545"]
    b = [BigInt.new(146), BigInt.new(3464), BigInt.new(97), BigInt.new(545)]
    expect(a).to eq(b)
  end

  it "can be casted into other Number types" do
    big = BigInt.new(1234567890)
    expect(big.to_i).to eq(1234567890)
    expect(big.to_i8).to eq(-46)
    expect(big.to_i16).to eq(722)
    expect(big.to_i32).to eq(1234567890)
    expect(big.to_i64).to eq(1234567890)
    expect(big.to_u).to eq(1234567890)
    expect(big.to_u8).to eq(210)
    expect(big.to_u16).to eq(722)
    expect(big.to_u32).to eq(1234567890)
    expect(big.to_u64).to eq(1234567890)
  end
end

