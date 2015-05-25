require "spec"

class TupleSpecObj
  getter x

  def initialize(@x)
  end

  def clone
    TupleSpecObj.new(@x)
  end
end

describe "Tuple" do
  it "does length" do
    {1, 2, 1, 2}.length.should eq(4)
  end

  it "does []" do
    a = {1, 2.5}
    i = 0
    a[i].should eq(1)
    i = 1
    a[i].should eq(2.5)
  end

  it "does [] raises index out of bounds" do
    a = {1, 2.5}
    i = 2
    expect_raises(IndexOutOfBounds) { a[i] }
    i = -1
    expect_raises(IndexOutOfBounds) { a[i] }
  end

  it "does []?" do
    a = {1, 2}
    a[1]?.should eq(2)
    a[2]?.should be_nil
  end

  it "does at" do
    a = {1, 2}
    a.at(1).should eq(2)

    expect_raises(IndexOutOfBounds) { a.at(2) }

    a.at(2) { 3 }.should eq(3)
  end

  describe "values_at" do
    it "returns the given indexes" do
      {"a", "b", "c", "d"}.values_at(1, 0, 2).should eq({"b", "a", "c"})
    end

    it "raises when passed an invalid index" do
      expect_raises IndexOutOfBounds do
        {"a"}.values_at(10)
      end
    end

    it "works with mixed types" do
      {1, "a", 1.0, :a}.values_at(0, 1, 2, 3).should eq({1, "a", 1.0, :a})
    end
  end

  it "does ==" do
    a = {1, 2}
    b = {3, 4}
    c = {1, 2, 3}
    d = {1}
    e = {1, 2}
    a.should eq(a)
    a.should eq(e)
    a.should_not eq(b)
    a.should_not eq(c)
    a.should_not eq(d)
  end

  it "does == with differnt types but same length" do
    {1, 2}.should eq({1.0, 2.0})
  end

  it "does == with another type" do
    {1, 2}.should_not eq(1)
  end

  it "does compare" do
    a = {1, 2}
    b = {3, 4}
    c = {1, 6}
    d = {3, 5}
    e = {0, 8}
    [a, b, c, d, e].sort.should eq([e, a, c, b, d])
    [a, b, c, d, e].min.should eq(e)
  end

  it "does compare with different lengths" do
    a = {2}
    b = {1, 2, 3}
    c = {1, 2}
    d = {1, 1}
    e = {1, 1, 3}
    [a, b, c, d, e].sort.should eq([d, e, c, b, a])
    [a, b, c, d, e].min.should eq(d)
  end

  it "does to_s" do
    {1, 2, 3}.to_s.should eq("{1, 2, 3}")
  end

  it "does each" do
    a = 0
    {1, 2, 3}.each do |i|
      a += i
    end
    a.should eq(6)
  end

  it "does dup" do
    r1, r2 = TupleSpecObj.new(10), TupleSpecObj.new(20)
    t = {r1, r2}
    u = t.dup
    u.length.should eq(2)
    u[0].should be(r1)
    u[1].should be(r2)
  end

  it "does clone" do
    r1, r2 = TupleSpecObj.new(10), TupleSpecObj.new(20)
    t = {r1, r2}
    u = t.clone
    u.length.should eq(2)
    u[0].x.should eq(r1.x)
    u[0].should_not be(r1)
    u[1].x.should eq(r2.x)
    u[1].should_not be(r2)
  end

  it "does Tuple#new" do
    Tuple.new(1, 2, 3).should eq({1, 2, 3})
  end

  it "clones empty tuple" do
    Tuple.new.clone.should eq(Tuple.new)
  end

  it "does iterator" do
    iter = {1, 2, 3}.each

    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should eq(3)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(1)
  end

  it "does map" do
    tuple = {1, 2.5, "a"}
    tuple2 = tuple.map &.to_s
    tuple2.should be_a(Tuple)
    tuple2.should eq({"1", "2.5", "a"})
  end

  it "gets first element" do
    tuple = {1, 2.5}
    tuple.first.should eq(1)
    typeof(tuple.first).should eq(Int32)
  end

  it "gets last element" do
    tuple = {1, 2.5, "a"}
    tuple.last.should eq("a")
    # typeof(tuple.last).should eq(String)
  end
end
