require "spec"
require "big_float"

describe "BigFloat" do
  describe "new" do
    string_of_integer_value = "123456789012345678901"
    bigfloat_of_integer_value = BigFloat.new(string_of_integer_value)
    string_of_float_value = "1234567890.12345678901"
    bigfloat_of_float_value = BigFloat.new(string_of_float_value)

    it "new(String)" do
      bigfloat_of_integer_value.to_s.should eq(string_of_integer_value)
      bigfloat_of_float_value.to_s.should eq(string_of_float_value)
    end

    it "new(BigInt)" do
      bigfloat_on_bigint_value = BigFloat.new(BigInt.new(string_of_integer_value))
      bigfloat_on_bigint_value.should eq(bigfloat_of_integer_value)
      bigfloat_on_bigint_value.to_s.should eq(string_of_integer_value)
    end

    it "new(BigRational)" do
      bigfloat_on_bigrational_value = BigFloat.new(BigRational.new(1, 3))
      bigfloat_on_bigrational_value.should eq(BigFloat.new(1) / BigFloat.new(3))
    end

    it "new(BigFloat)" do
      BigFloat.new(bigfloat_of_integer_value).should eq(bigfloat_of_integer_value)
      BigFloat.new(bigfloat_of_float_value).should eq(bigfloat_of_float_value)
    end

    it "new(Int)" do
      BigFloat.new(1_u8).to_s.should eq("1")
      BigFloat.new(1_u16).to_s.should eq("1")
      BigFloat.new(1_u32).to_s.should eq("1")
      BigFloat.new(1_u64).to_s.should eq("1")
      BigFloat.new(1_i8).to_s.should eq("1")
      BigFloat.new(1_i16).to_s.should eq("1")
      BigFloat.new(1_i32).to_s.should eq("1")
      BigFloat.new(1_i64).to_s.should eq("1")
      BigFloat.new(-1_i8).to_s.should eq("-1")
      BigFloat.new(-1_i16).to_s.should eq("-1")
      BigFloat.new(-1_i32).to_s.should eq("-1")
      BigFloat.new(-1_i64).to_s.should eq("-1")

      BigFloat.new(255_u8).to_s.should eq("255")
      BigFloat.new(65535_u16).to_s.should eq("65535")
      BigFloat.new(4294967295_u32).to_s.should eq("4294967295")
      BigFloat.new(18446744073709551615_u64).to_s.should eq("18446744073709551615")
      BigFloat.new(127_i8).to_s.should eq("127")
      BigFloat.new(32767_i16).to_s.should eq("32767")
      BigFloat.new(2147483647_i32).to_s.should eq("2147483647")
      BigFloat.new(9223372036854775807_i64).to_s.should eq("9223372036854775807")
      BigFloat.new(-128_i8).to_s.should eq("-128")
      BigFloat.new(-32768_i16).to_s.should eq("-32768")
      BigFloat.new(-2147483648_i32).to_s.should eq("-2147483648")
      BigFloat.new(-9223372036854775808_i64).to_s.should eq("-9223372036854775808")
    end
  end

  describe "-@" do
    bf = "0.12345".to_big_f
    it { (-bf).to_s.should eq("-0.12345") }

    bf = "61397953.0005354".to_big_f
    it { (-bf).to_s.should eq("-61397953.0005354") }

    bf = "395.009631567315769036".to_big_f
    it { (-bf).to_s.should eq("-395.009631567315769036") }
  end

  describe "+" do
    it { ("1.0".to_big_f + "2.0".to_big_f).to_s.should eq("3") }
    it { ("0.04".to_big_f + "89.0001".to_big_f).to_s.should eq("89.0401") }
    it { ("-5.5".to_big_f + "5.5".to_big_f).to_s.should eq("0") }
    it { ("5.5".to_big_f + "-5.5".to_big_f).to_s.should eq("0") }
  end

  describe "-" do
    it { ("1.0".to_big_f - "2.0".to_big_f).to_s.should eq("-1") }
    it { ("0.04".to_big_f - "89.0001".to_big_f).to_s.should eq("-88.9601") }
    it { ("-5.5".to_big_f - "5.5".to_big_f).to_s.should eq("-11") }
    it { ("5.5".to_big_f - "-5.5".to_big_f).to_s.should eq("11") }
  end

  describe "*" do
    it { ("1.0".to_big_f * "2.0".to_big_f).to_s.should eq("2") }
    it { ("0.04".to_big_f * "89.0001".to_big_f).to_s.should eq("3.560004") }
    it { ("-5.5".to_big_f * "5.5".to_big_f).to_s.should eq("-30.25") }
    it { ("5.5".to_big_f * "-5.5".to_big_f).to_s.should eq("-30.25") }
  end

  describe "/" do
    it { ("1.0".to_big_f / "2.0".to_big_f).to_s.should eq("0.5") }
    it { ("0.04".to_big_f / "89.0001".to_big_f).to_s.should eq("0.000449437697261014313467") }
    it { ("-5.5".to_big_f / "5.5".to_big_f).to_s.should eq("-1") }
    it { ("5.5".to_big_f / "-5.5".to_big_f).to_s.should eq("-1") }
    expect_raises(DivisionByZero) { 0.1.to_big_f / 0 }
    it { ("5.5".to_big_f / 16_u64).to_s.should eq("0.34375") }
    it { ("5.5".to_big_f / 16_u8).to_s.should eq("0.34375") }
  end

  describe "**" do
    # TODO: investigate why in travis this gives ""1.79559999999999999991"
    # it { ("1.34".to_big_f ** 2).to_s.should eq("1.79559999999999999994") }
    it { ("-0.05".to_big_f ** 10).to_s.should eq("0.00000000000009765625") }
    it { (0.1234567890.to_big_f ** 3).to_s.should eq("0.00188167637178915473909") }
  end

  describe "abs" do
    it { -5.to_big_f.abs.should eq(5) }
    it { 5.to_big_f.abs.should eq(5) }
    it { "-0.00001".to_big_f.abs.to_s.should eq("0.00001") }
    it { "0.00000000001".to_big_f.abs.to_s.should eq("0.00000000001") }
  end

  describe "ceil" do
    it { 2.0.to_big_f.ceil.should eq(2) }
    it { 2.1.to_big_f.ceil.should eq(3) }
    it { 2.9.to_big_f.ceil.should eq(3) }
  end

  describe "floor" do
    it { 2.1.to_big_f.floor.should eq(2) }
    it { 2.9.to_big_f.floor.should eq(2) }
    it { -2.9.to_big_f.floor.should eq(-3) }
  end

  describe "trunc" do
    it { 2.1.to_big_f.trunc.should eq(2) }
    it { 2.9.to_big_f.trunc.should eq(2) }
    it { -2.9.to_big_f.trunc.should eq(-2) }
  end

  describe "to_f" do
    it { 1.34.to_big_f.to_f.should eq(1.34) }
    it { 0.0001304.to_big_f.to_f.should eq(0.0001304) }
    it { 1.234567.to_big_f.to_f32.should eq(1.234567_f32) }
  end

  describe "to_i" do
    it { 1.34.to_big_f.to_i.should eq(1) }
    it { 123.to_big_f.to_i.should eq(123) }
    it { -4321.to_big_f.to_i.should eq(-4321) }
  end

  describe "to_u" do
    it { 1.34.to_big_f.to_u.should eq(1) }
    it { 123.to_big_f.to_u.should eq(123) }
    it { 4321.to_big_f.to_u.should eq(4321) }
  end

  describe "to_s" do
    it { "0".to_big_f.to_s.should eq("0") }
    it { "0.000001".to_big_f.to_s.should eq("0.000001") }
    it { "48600000".to_big_f.to_s.should eq("48600000") }
    it { "12345678.87654321".to_big_f.to_s.should eq("12345678.87654321") }
    it { "9.000000000000987".to_big_f.to_s.should eq("9.000000000000987") }
    it { "12345678901234567".to_big_f.to_s.should eq("12345678901234567") }
    it { "1234567890123456789".to_big_f.to_s.should eq("1234567890123456789") }
  end

  describe "#inspect" do
    it { "2.3".to_big_f.inspect.should eq("2.3_big_f") }
  end

  it "#hash" do
    b = 123.to_big_f
    b.hash.should eq(b.to_f64.hash)
  end

  it "clones" do
    x = 1.to_big_f
    x.clone.should eq(x)
  end
end

describe "BigFloat Math" do
  it "frexp" do
    Math.frexp(0.2.to_big_f).should eq({0.8, -2})
  end
end
