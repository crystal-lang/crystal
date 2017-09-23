require "spec"
require "big_rational"

private def br(n, d)
  BigRational.new(n, d)
end

private def test_comp(val, less, equal, greater, file = __FILE__, line = __LINE__)
  (val < greater).should eq(true), file, line
  (greater < val).should eq(false), file, line
  (val <=> greater).should eq(-1), file, line
  (greater <=> val).should eq(1), file, line

  (val == equal).should eq(true), file, line
  (equal == val).should eq(true), file, line
  (val <=> equal).should eq(0), file, line
  (equal <=> val).should eq(0), file, line

  (val > less).should eq(true), file, line
  (less > val).should eq(false), file, line
  (val <=> less).should eq(1), file, line
  (less <=> val).should eq(-1), file, line
end

describe BigRational do
  it "initialize" do
    BigRational.new(BigInt.new(10), BigInt.new(3))
               .should eq(BigRational.new(10, 3))

    expect_raises(DivisionByZero) do
      BigRational.new(BigInt.new(2), BigInt.new(0))
    end

    expect_raises(DivisionByZero) do
      BigRational.new(2, 0)
    end
  end

  it "#numerator" do
    br(10, 3).numerator.should eq(BigInt.new(10))
  end

  it "#denominator" do
    br(10, 3).denominator.should eq(BigInt.new(3))
  end

  it "#to_s" do
    br(10, 3).to_s.should eq("10/3")
    br(90, 3).to_s.should eq("30")
    br(1, 98).to_s.should eq("1/98")

    r = BigRational.new(8243243, 562828882)
    r.to_s(16).should eq("7dc82b/218c1652")
    r.to_s(36).should eq("4woiz/9b3djm")
  end

  it "#to_f64" do
    r = br(10, 3)
    f = 10.to_f64 / 3.to_f64
    r.to_f64.should be_close(f, 0.001)
  end

  it "#to_f" do
    r = br(10, 3)
    f = 10.to_f64 / 3.to_f64
    r.to_f.should be_close(f, 0.001)
  end

  it "#to_f32" do
    r = br(10, 3)
    f = 10.to_f32 / 3.to_f32
    r.to_f32.should be_close(f, 0.001)
  end

  it "#to_big_f" do
    r = br(10, 3)
    f = 10.to_big_f / 3.to_big_f
    r.to_big_f.should be_close(f, 0.001)
  end

  it "Int#to_big_r" do
    3.to_big_r.should eq(br(3, 1))
  end

  it "Float32#to_big_r" do
    0.3333333333333333333333_f32.to_big_r.should eq(br(11184811, 33554432))
  end

  it "Float64#to_big_r" do
    0.3333333333333333333333_f64.to_big_r.should eq(br(6004799503160661, 18014398509481984))
  end

  it "#<=>(:BigRational) and Comparable" do
    a = br(11, 3)
    l = br(10, 3)
    e = a
    g = br(12, 3)

    # sanity check things aren't swapped
    [l, e, g].each { |o| (a <=> o).should eq(a.to_f <=> o.to_f) }

    test_comp(a, l, e, g)
  end

  it "#<=>(:Int) and Comparable" do
    test_comp(br(10, 2), 4_i32, 5_i32, 6_i32)
    test_comp(br(10, 2), 4_i64, 5_i64, 6_i64)
  end

  it "#<=>(:BigInt) and Comparable" do
    test_comp(br(10, 2), BigInt.new(4), BigInt.new(5), BigInt.new(6))
  end

  it "#<=>(:Float) and Comparable" do
    test_comp(br(10, 2), 4.0_f32, 5.0_f32, 6.0_f32)
    test_comp(br(10, 2), 4.0_f64, 5.0_f64, 6.0_f64)
  end

  it "#+" do
    (br(10, 7) + br(3, 7)).should eq(br(13, 7))
    (0 + br(10, 7) + 3).should eq(br(31, 7))
  end

  it "#-" do
    (br(10, 7) - br(3, 7)).should eq(br(7, 7))
    (br(10, 7) - 3).should eq(br(-11, 7))
    (0 - br(10, 7)).should eq(br(-10, 7))
  end

  it "#*" do
    (br(10, 7) * br(3, 7)).should eq(br(30, 49))
    (1 * br(10, 7) * 3).should eq(br(30, 7))
  end

  it "#/" do
    (br(10, 7) / br(3, 7)).should eq(br(10, 3))
    expect_raises(DivisionByZero) { br(10, 7) / br(0, 10) }
    (br(10, 7) / 3).should eq(br(10, 21))
    (1 / br(10, 7)).should eq(br(7, 10))
  end

  it "#- (negation)" do
    (-br(10, 3)).should eq(br(-10, 3))
  end

  it "#inv" do
    (br(10, 3).inv).should eq(br(3, 10))
    expect_raises(DivisionByZero) { br(0, 3).inv }
  end

  it "#abs" do
    (br(-10, 3).abs).should eq(br(10, 3))
  end

  it "#<<" do
    (br(10, 3) << 2).should eq(br(40, 3))
  end

  it "#>>" do
    (br(10, 3) >> 2).should eq(br(5, 6))
  end

  it "#hash" do
    b = br(10, 3)
    hash = b.hash
    hash.should eq(b.to_f64.hash)
  end

  it "is a number" do
    br(10, 3).is_a?(Number).should be_true
  end

  it "clones" do
    x = br(10, 3)
    x.clone.should eq(x)
  end
end
