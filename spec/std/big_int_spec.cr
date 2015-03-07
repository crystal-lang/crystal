require "spec"
require "big_int"

describe "BigInt" do
  it "creates with a value of zero" do
    BigInt.new.to_s.should eq("0")
  end

  it "creates from signed ints" do
    BigInt.new(-1_i8).to_s.should eq("-1")
    BigInt.new(-1_i16).to_s.should eq("-1")
    BigInt.new(-1_i32).to_s.should eq("-1")
    BigInt.new(-1_i64).to_s.should eq("-1")
  end

  it "creates from unsigned ints" do
    BigInt.new(1_u8).to_s.should eq("1")
    BigInt.new(1_u16).to_s.should eq("1")
    BigInt.new(1_u32).to_s.should eq("1")
    BigInt.new(1_u64).to_s.should eq("1")
  end

  it "creates from string" do
    BigInt.new("12345678").to_s.should eq("12345678")
  end

  it "compares" do
    1.to_big_i.should eq(1.to_big_i)
    1.to_big_i.should eq(1)
    1.to_big_i.should eq(1_u8)

    [3.to_big_i, 2.to_big_i, 10.to_big_i, 4, 8_u8].sort.should eq([2, 3, 4, 8, 10])
  end

  it "adds" do
    (1.to_big_i + 2.to_big_i).should eq(3.to_big_i)
    (1.to_big_i + 2).should eq(3.to_big_i)
    (1.to_big_i + 2_u8).should eq(3.to_big_i)
    (5.to_big_i + (-2_i64)).should eq(3.to_big_i)

    (2 + 1.to_big_i).should eq(3.to_big_i)
  end

  it "subs" do
    (5.to_big_i - 2.to_big_i).should eq(3.to_big_i)
    (5.to_big_i - 2).should eq(3.to_big_i)
    (5.to_big_i - 2_u8).should eq(3.to_big_i)
    (5.to_big_i - (-2_i64)).should eq(7.to_big_i)

    (5 - 1.to_big_i).should eq(4.to_big_i)
    (-5 - 1.to_big_i).should eq(-6.to_big_i)
  end

  it "negates" do
    (-(-123.to_big_i)).should eq(123.to_big_i)
  end

  it "multiplies" do
    (2.to_big_i * 3.to_big_i).should eq(6.to_big_i)
    (2.to_big_i * 3).should eq(6.to_big_i)
    (2.to_big_i * 3_u8).should eq(6.to_big_i)
    (3 * 2.to_big_i).should eq(6.to_big_i)
    (3_u8 * 2.to_big_i).should eq(6.to_big_i)
  end

  it "gets absolute value" do
    (-10.to_big_i.abs).should eq(10.to_big_i)
  end

  it "divides" do
    (10.to_big_i / 3.to_big_i).should eq(3.to_big_i)
    (10.to_big_i / 3).should eq(3.to_big_i)
    (10.to_big_i / -3).should eq(-3.to_big_i)
    (10 / 3.to_big_i).should eq(3.to_big_i)
  end

  it "does modulo" do
    (10.to_big_i % 3.to_big_i).should eq(1.to_big_i)
    (10.to_big_i % 3).should eq(1.to_big_i)
    (10.to_big_i % -3).should eq(1.to_big_i)
    (10 % 3.to_big_i).should eq(1.to_big_i)
  end

  it "does bitwise and" do
    (123.to_big_i & 321).should eq(65)
    (BigInt.new("96238761238973286532") & 86325735648).should eq(69124358272)
  end

  it "does bitwise or" do
    (123.to_big_i | 4).should eq(127)
    (BigInt.new("96238761238986532") | 8632573).should eq(96238761247506429)
  end

  it "does bitwise xor" do
    (123.to_big_i ^ 50).should eq(73)
    (BigInt.new("96238761238986532") ^ 8632573).should eq(96238761247393753)
  end

  it "does bitwise not" do
    (~123).should eq(-124)

    a = BigInt.new("192623876123689865327")
    b = BigInt.new("-192623876123689865328")
    (~a).should eq(b)
  end

  it "does bitwise right shift" do
    (123.to_big_i >> 4).should eq(7)
    (123456.to_big_i >> 8).should eq(482)
  end

  it "does bitwise left shift" do
    (123.to_big_i << 4).should eq(1968)
    (123456.to_big_i << 8).should eq(31604736)
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
    a.to_s(2).should eq(b)
    a.to_s(16).should eq(c)
    a.to_s(32).should eq(d)
  end

  it "casts other ints and strings" do
    a = BigInt.new(123456)
    b = BigInt.cast(123456)
    a.should eq(b)

    a = BigInt.new("123456789012345678901234567890")
    b = BigInt.cast("123456789012345678901234567890")
    a.should eq(b)
  end

  it "can use Number::[]" do
    a = BigInt[146, "3464", 97, "545"]
    b = [BigInt.new(146), BigInt.new(3464), BigInt.new(97), BigInt.new(545)]
    a.should eq(b)
  end

  it "can be casted into other Number types" do
    big = BigInt.new(1234567890)
    big.to_i.should eq(1234567890)
    big.to_i8.should eq(-46)
    big.to_i16.should eq(722)
    big.to_i32.should eq(1234567890)
    big.to_i64.should eq(1234567890)
    big.to_u.should eq(1234567890)
    big.to_u8.should eq(210)
    big.to_u16.should eq(722)
    big.to_u32.should eq(1234567890)
    big.to_u64.should eq(1234567890)
  end
end

