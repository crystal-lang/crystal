require "spec"

private class TupleSpecObj
  getter x : Int32

  def initialize(@x)
  end

  def clone
    TupleSpecObj.new(@x)
  end
end

describe "Tuple" do
  it "does size" do
    {1, 2, 1, 2}.size.should eq(4)
  end

  it "checks empty?" do
    Tuple.new.empty?.should be_true
    {1}.empty?.should be_false
  end

  it "does []" do
    a = {1, 2.5}
    i = 0
    a[i].should eq(1)
    i = 1
    a[i].should eq(2.5)
    i = -1
    a[i].should eq(2.5)
    i = -2
    a[i].should eq(1)
  end

  it "does [] raises index out of bounds" do
    a = {1, 2.5}
    i = 2
    expect_raises(IndexError) { a[i] }
    i = -3
    expect_raises(IndexError) { a[i] }
  end

  it "does []?" do
    a = {1, 2}
    i = 1
    a[i]?.should eq(2)
    i = -1
    a[i]?.should eq(2)
    i = 2
    a[i]?.should be_nil
    i = -3
    a[i]?.should be_nil
  end

  it "does at" do
    a = {1, 2}
    a.at(1).should eq(2)
    a.at(-1).should eq(2)

    expect_raises(IndexError) { a.at(2) }
    expect_raises(IndexError) { a.at(-3) }

    a.at(2) { 3 }.should eq(3)
    a.at(-3) { 3 }.should eq(3)
  end

  describe "values_at" do
    it "returns the given indexes" do
      {"a", "b", "c", "d"}.values_at(1, 0, 2).should eq({"b", "a", "c"})
    end

    it "raises when passed an invalid index" do
      expect_raises IndexError do
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

  it "does == with different types but same size" do
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

  it "does compare with different sizes" do
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
    end.should be_nil
    a.should eq(6)
  end

  it "does dup" do
    r1, r2 = TupleSpecObj.new(10), TupleSpecObj.new(20)
    t = {r1, r2}
    u = t.dup
    u.size.should eq(2)
    u[0].should be(r1)
    u[1].should be(r2)
  end

  it "does clone" do
    r1, r2 = TupleSpecObj.new(10), TupleSpecObj.new(20)
    t = {r1, r2}
    u = t.clone
    u.size.should eq(2)
    u[0].x.should eq(r1.x)
    u[0].should_not be(r1)
    u[1].x.should eq(r2.x)
    u[1].should_not be(r2)
  end

  it "does Tuple.new" do
    Tuple.new(1, 2, 3).should eq({1, 2, 3})
    Tuple.new([1, 2, 3]).should eq({[1, 2, 3]})
  end

  it "does Tuple.from" do
    t = Tuple(Int32, Float64).from([1_i32, 2.0_f64])
    t.should eq({1_i32, 2.0_f64})
    t.class.should eq(Tuple(Int32, Float64))

    expect_raises ArgumentError do
      Tuple(Int32).from([1, 2])
    end

    expect_raises(TypeCastError, /cast from String to Int32 failed/) do
      Tuple(Int32, String).from(["foo", 1])
    end
  end

  it "does Tuple#from" do
    t = {Int32, Float64}.from([1_i32, 2.0_f64])
    t.should eq({1_i32, 2.0_f64})
    t.class.should eq(Tuple(Int32, Float64))

    expect_raises ArgumentError do
      {Int32}.from([1, 2])
    end

    expect_raises(TypeCastError, /cast from String to Int32 failed/) do
      {Int32, String}.from(["foo", 1])
    end
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
    tuple2.is_a?(Tuple).should be_true
    tuple2.should eq({"1", "2.5", "a"})
  end

  it "does reverse" do
    {1, 2.5, "a", 'c'}.reverse.should eq({'c', "a", 2.5, 1})
  end

  it "does reverse_each" do
    str = ""
    {"a", "b", "c"}.reverse_each do |i|
      str += i
    end.should be_nil
    str.should eq("cba")
  end

  describe "reverse_each iterator" do
    it "does next" do
      a = {1, 2, 3}
      iter = a.reverse_each
      iter.next.should eq(3)
      iter.next.should eq(2)
      iter.next.should eq(1)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(3)
    end
  end

  it "gets first element" do
    tuple = {1, 2.5}
    tuple.first.should eq(1)
    typeof(tuple.first).should eq(Int32)
  end

  it "gets first? element" do
    tuple = {1, 2.5}
    tuple.first?.should eq(1)

    Tuple.new.first?.should be_nil
  end

  it "gets last element" do
    tuple = {1, 2.5, "a"}
    tuple.last.should eq("a")
    typeof(tuple.last).should eq(String)
  end

  it "gets last? element" do
    tuple = {1, 2.5, "a"}
    tuple.last?.should eq("a")

    Tuple.new.last?.should be_nil
  end

  it "does comparison" do
    tuple1 = {"a", "a", "c"}
    tuple2 = {"a", "b", "c"}
    (tuple1 <=> tuple2).should eq(-1)
    (tuple2 <=> tuple1).should eq(1)
  end

  it "does <=> for equality" do
    tuple1 = {0, 1}
    tuple2 = {0.0, 1}
    (tuple1 <=> tuple2).should eq(0)
  end

  it "does <=> with the same beginning and different size" do
    tuple1 = {1, 2, 3}
    tuple2 = {1, 2}
    (tuple1 <=> tuple2).should eq(1)
  end

  it "does types" do
    tuple = {1, 'a', "hello"}
    tuple.class.types.to_s.should eq("{Int32, Char, String}")
  end

  it "does ===" do
    ({1, 2} === {1, 2}).should be_true
    ({1, 2} === {1, 3}).should be_false
    ({1, 2, 3} === {1, 2}).should be_false
    ({/o+/, "bar"} === {"fox", "bar"}).should be_true
    ({1, 2} === nil).should be_false
  end
end
