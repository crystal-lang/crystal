require "spec"
require "big_float"

describe "BigFloat" do
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
