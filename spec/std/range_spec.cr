require "spec"
require "big_int"

struct RangeSpecIntWrapper
  include Comparable(self)

  getter value : Int32

  def initialize(@value)
  end

  def succ
    RangeSpecIntWrapper.new(@value + 1)
  end

  def <=>(other)
    value <=> other.value
  end

  def self.zero
    RangeSpecIntWrapper.new(0)
  end

  def +(other : RangeSpecIntWrapper)
    RangeSpecIntWrapper.new(value + other.value)
  end
end

describe "Range" do
  it "initialized with new method" do
    Range.new(1, 10).should eq(1..10)
    Range.new(1, 10, false).should eq(1..10)
    Range.new(1, 10, true).should eq(1...10)
  end

  it "gets basic properties" do
    r = 1..5
    r.begin.should eq(1)
    r.end.should eq(5)
    r.excludes_end?.should be_false

    r = 1...5
    r.begin.should eq(1)
    r.end.should eq(5)
    r.excludes_end?.should be_true
  end

  it "includes?" do
    (1..5).includes?(1).should be_true
    (1..5).includes?(5).should be_true

    (1...5).includes?(1).should be_true
    (1...5).includes?(5).should be_false
  end

  it "does to_s" do
    (1...5).to_s.should eq("1...5")
    (1..5).to_s.should eq("1..5")
  end

  it "does inspect" do
    (1...5).inspect.should eq("1...5")
  end

  it "is empty with .. and begin > end" do
    (1..0).to_a.empty?.should be_true
  end

  it "is empty with ... and begin > end" do
    (1...0).to_a.empty?.should be_true
  end

  it "is not empty with .. and begin == end" do
    (1..1).to_a.should eq([1])
  end

  it "is not empty with ... and begin.succ == end" do
    (1...2).to_a.should eq([1])
  end

  describe "sum" do
    it "called with no block is specialized for performance" do
      (1..3).sum.should eq 6
      (1...3).sum.should eq 3
      (BigInt.new("1")..BigInt.new("1 000 000 000")).sum.should eq BigInt.new("500 000 000 500 000 000")
      (1..3).sum(4).should eq 10
      (3..1).sum(4).should eq 4
      (1..11).step(2).sum.should eq 36
      (1...11).step(2).sum.should eq 25
      (BigInt.new("1")..BigInt.new("1 000 000 000")).step(2).sum.should eq BigInt.new("250 000 000 000 000 000")
    end

    it "is equivalent to Enumerable#sum" do
      (1..3).sum { |x| x * 2 }.should eq 12
      (1..3).step(2).sum { |x| x * 2 }.should eq 8
      (RangeSpecIntWrapper.new(1)..RangeSpecIntWrapper.new(3)).sum.should eq RangeSpecIntWrapper.new(6)
      (RangeSpecIntWrapper.new(1)..RangeSpecIntWrapper.new(3)).step(2).sum.should eq RangeSpecIntWrapper.new(4)
    end
  end

  describe "each" do
    it "gives correct values with inclusive range" do
      range = -1..3
      arr = [] of Int32
      range.each { |x| arr << x }
      arr.should eq([-1, 0, 1, 2, 3])
    end

    it "gives correct values with exclusive range" do
      range = 'a'...'c'
      arr = [] of Char
      range.each { |x| arr << x }
      arr.should eq(['a', 'b'])
    end

    it "is empty with empty inclusive range" do
      range = 0..-1
      any = false
      range.each { any = true }
      any.should eq(false)
    end
  end

  describe "reverse_each" do
    it "gives correct values with inclusive range" do
      range = 'a'..'c'
      arr = [] of Char
      range.reverse_each { |x| arr << x }
      arr.should eq(['c', 'b', 'a'])
    end

    it "gives correct values with exclusive range" do
      range = -1...3
      arr = [] of Int32
      range.reverse_each { |x| arr << x }
      arr.should eq([2, 1, 0, -1])
    end

    it "is empty with empty inclusive range" do
      range = 0..-1
      any = false
      range.reverse_each { any = true }
      any.should eq(false)
    end
  end

  describe "each iterator" do
    it "does next with inclusive range" do
      a = 1..3
      iter = a.each
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "does next with exclusive range" do
      r = 1...3
      iter = r.each
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "cycles" do
      (1..3).cycle.first(8).join.should eq("12312312")
    end

    it "is empty with .. and begin > end" do
      (1..0).each.to_a.empty?.should be_true
    end

    it "is empty with ... and begin > end" do
      (1...0).each.to_a.empty?.should be_true
    end

    it "is not empty with .. and begin == end" do
      (1..1).each.to_a.should eq([1])
    end

    it "is not empty with ... and begin.succ == end" do
      (1...2).each.to_a.should eq([1])
    end
  end

  describe "step iterator" do
    it "does next with inclusive range" do
      a = 1..5
      iter = a.step(2)
      iter.next.should eq(1)
      iter.next.should eq(3)
      iter.next.should eq(5)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "does next with exclusive range" do
      a = 1...5
      iter = a.step(2)
      iter.next.should eq(1)
      iter.next.should eq(3)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "does next with exclusive range (2)" do
      a = 1...6
      iter = a.step(2)
      iter.next.should eq(1)
      iter.next.should eq(3)
      iter.next.should eq(5)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "is empty with .. and begin > end" do
      (1..0).step(1).to_a.empty?.should be_true
    end

    it "is empty with ... and begin > end" do
      (1...0).step(1).to_a.empty?.should be_true
    end

    it "is not empty with .. and begin == end" do
      (1..1).step(1).to_a.should eq([1])
    end

    it "is not empty with ... and begin.succ == end" do
      (1...2).step(1).to_a.should eq([1])
    end
  end
end
