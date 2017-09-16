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

  it "raises if creates from string but invalid" do
    expect_raises ArgumentError, "Invalid BigInt: 123 hello 456" do
      BigInt.new("123 hello 456")
    end
  end

  it "creates from float" do
    BigInt.new(12.3).to_s.should eq("12")
  end

  it "compares" do
    1.to_big_i.should eq(1.to_big_i)
    1.to_big_i.should eq(1)
    1.to_big_i.should eq(1_u8)

    [3.to_big_i, 2.to_big_i, 10.to_big_i, 4, 8_u8].sort.should eq([2, 3, 4, 8, 10])
  end

  it "compares against float" do
    1.to_big_i.should eq(1.0)
    1.to_big_i.should eq(1.0_f32)
    1.to_big_i.should_not eq(1.1)
    1.0.should eq(1.to_big_i)
    1.0_f32.should eq(1.to_big_i)
    1.1.should_not eq(1.to_big_i)

    [1.1, 1.to_big_i, 3.to_big_i, 2.2].sort.should eq([1, 1.1, 2.2, 3])
  end

  it "divides and calculs the modulo" do
    11.to_big_i.divmod(3.to_big_i).should eq({3, 2})
    11.to_big_i.divmod(-3.to_big_i).should eq({-4, -1})

    11.to_big_i.divmod(3_i32).should eq({3, 2})
    11.to_big_i.divmod(-3_i32).should eq({-4, -1})

    10.to_big_i.divmod(2).should eq({5, 0})
    11.to_big_i.divmod(2).should eq({5, 1})

    10.to_big_i.divmod(2.to_big_i).should eq({5, 0})
    11.to_big_i.divmod(2.to_big_i).should eq({5, 1})

    10.to_big_i.divmod(-2).should eq({-5, 0})
    11.to_big_i.divmod(-2).should eq({-6, -1})

    -10.to_big_i.divmod(2).should eq({-5, 0})
    -11.to_big_i.divmod(2).should eq({-6, 1})

    -10.to_big_i.divmod(-2).should eq({5, 0})
    -11.to_big_i.divmod(-2).should eq({5, -1})
  end

  it "adds" do
    (1.to_big_i + 2.to_big_i).should eq(3.to_big_i)
    (1.to_big_i + 2).should eq(3.to_big_i)
    (1.to_big_i + 2_u8).should eq(3.to_big_i)
    (5.to_big_i + (-2_i64)).should eq(3.to_big_i)
    (5.to_big_i + Int64::MAX).should be > Int64::MAX.to_big_i
    (5.to_big_i + Int64::MAX).should eq(Int64::MAX.to_big_i + 5)

    (2 + 1.to_big_i).should eq(3.to_big_i)
  end

  it "subs" do
    (5.to_big_i - 2.to_big_i).should eq(3.to_big_i)
    (5.to_big_i - 2).should eq(3.to_big_i)
    (5.to_big_i - 2_u8).should eq(3.to_big_i)
    (5.to_big_i - (-2_i64)).should eq(7.to_big_i)
    (-5.to_big_i - Int64::MAX).should be < -Int64::MAX.to_big_i
    (-5.to_big_i - Int64::MAX).should eq(-Int64::MAX.to_big_i - 5)

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
    (2.to_big_i * Int64::MAX).should eq(2.to_big_i * Int64::MAX.to_big_i)
  end

  it "gets absolute value" do
    (-10.to_big_i.abs).should eq(10.to_big_i)
  end

  it "divides" do
    (10.to_big_i / 3.to_big_i).should eq(3.to_big_i)
    (10.to_big_i / 3).should eq(3.to_big_i)
    (10 / 3.to_big_i).should eq(3.to_big_i)
    ((Int64::MAX.to_big_i * 2.to_big_i) / Int64::MAX).should eq(2.to_big_i)
  end

  it "divides with negative numbers" do
    (7.to_big_i / 2).should eq(3.to_big_i)
    (7.to_big_i / 2.to_big_i).should eq(3.to_big_i)
    (7.to_big_i / -2).should eq(-4.to_big_i)
    (7.to_big_i / -2.to_big_i).should eq(-4.to_big_i)
    (-7.to_big_i / 2).should eq(-4.to_big_i)
    (-7.to_big_i / 2.to_big_i).should eq(-4.to_big_i)
    (-7.to_big_i / -2).should eq(3.to_big_i)
    (-7.to_big_i / -2.to_big_i).should eq(3.to_big_i)

    (-6.to_big_i / 2).should eq(-3.to_big_i)
    (6.to_big_i / -2).should eq(-3.to_big_i)
    (-6.to_big_i / -2).should eq(3.to_big_i)
  end

  it "tdivs" do
    5.to_big_i.tdiv(3).should eq(1)
    -5.to_big_i.tdiv(3).should eq(-1)
    5.to_big_i.tdiv(-3).should eq(-1)
    -5.to_big_i.tdiv(-3).should eq(1)
  end

  it "does modulo" do
    (10.to_big_i % 3.to_big_i).should eq(1.to_big_i)
    (10.to_big_i % 3).should eq(1.to_big_i)
    (10 % 3.to_big_i).should eq(1.to_big_i)
  end

  it "does modulo with negative numbers" do
    (7.to_big_i % 2).should eq(1.to_big_i)
    (7.to_big_i % 2.to_big_i).should eq(1.to_big_i)
    (7.to_big_i % -2).should eq(-1.to_big_i)
    (7.to_big_i % -2.to_big_i).should eq(-1.to_big_i)
    (-7.to_big_i % 2).should eq(1.to_big_i)
    (-7.to_big_i % 2.to_big_i).should eq(1.to_big_i)
    (-7.to_big_i % -2).should eq(-1.to_big_i)
    (-7.to_big_i % -2.to_big_i).should eq(-1.to_big_i)

    (6.to_big_i % 2).should eq(0.to_big_i)
    (6.to_big_i % -2).should eq(0.to_big_i)
    (-6.to_big_i % 2).should eq(0.to_big_i)
    (-6.to_big_i % -2).should eq(0.to_big_i)
  end

  it "does remainder with negative numbers" do
    5.to_big_i.remainder(3).should eq(2)
    -5.to_big_i.remainder(3).should eq(-2)
    5.to_big_i.remainder(-3).should eq(2)
    -5.to_big_i.remainder(-3).should eq(-2)
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

  it "exponentiates" do
    result = (2.to_big_i ** 1000)
    result.should be_a(BigInt)
    result.to_s.should eq("10715086071862673209484250490600018105614048117055336074437503883703510511249361224931983788156958581275946729175531468251871452856923140435984577574698574803934567774824230985421074605062371141877954182153046474983581941267398767559165543946077062914571196477686542167660429831652624386837205668069376")
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

  it "does to_big_f" do
    a = BigInt.new("1234567890123456789")
    a.to_big_f.should eq(BigFloat.new("1234567890123456789.0"))
  end

  describe "#inspect" do
    it { "2".to_big_i.inspect.should eq("2_big_i") }
  end

  it "does gcd and lcm" do
    # 3 primes
    a = BigInt.new("48112959837082048697")
    b = BigInt.new("12764787846358441471")
    c = BigInt.new("36413321723440003717")
    abc = a * b * c
    a_17 = a * 17

    (abc * b).gcd(abc * c).should eq(abc)
    (abc * b).lcm(abc * c).should eq(abc * b * c)
    (abc * b).gcd(abc * c).should be_a(BigInt)

    (a_17).gcd(17).should eq(17)
    (17).gcd(a_17).should eq(17)
    (-a_17).gcd(17).should eq(17)
    (-17).gcd(a_17).should eq(17)

    (a_17).gcd(17).should be_a(Int::Unsigned)
    (17).gcd(a_17).should be_a(Int::Unsigned)

    (a_17).lcm(17).should eq(a_17)
    (17).lcm(a_17).should eq(a_17)
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

    u64 = big.to_u64
    u64.should eq(1234567890)
    u64.should be_a(UInt64)
  end

  {% if flag?(:x86_64) %}
    # For 32 bits libgmp can't seem to be able to do it
    it "can cast UInt64::MAX to UInt64 (#2264)" do
      BigInt.new(UInt64::MAX).to_u64.should eq(UInt64::MAX)
    end
  {% end %}

  it "does String#to_big_i" do
    "123456789123456789".to_big_i.should eq(BigInt.new("123456789123456789"))
    "abcabcabcabcabcabc".to_big_i(base: 16).should eq(BigInt.new("3169001976782853491388"))
  end

  it "does popcount" do
    5.to_big_i.popcount.should eq(2)
  end

  it "#hash" do
    b1 = 5.to_big_i
    b2 = 5.to_big_i
    b3 = 6.to_big_i

    b1.hash.should eq(b2.hash)
    b1.hash.should_not eq(b3.hash)
  end

  it "clones" do
    x = 1.to_big_i
    x.clone.should eq(x)
  end
end
