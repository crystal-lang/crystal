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

  describe "bsearch" do
    it "Int" do
      ary = [3, 4, 7, 9, 12]
      (0...ary.size).bsearch { |i| ary[i] >= 2 }.should eq 0
      (0...ary.size).bsearch { |i| ary[i] >= 4 }.should eq 1
      (0...ary.size).bsearch { |i| ary[i] >= 6 }.should eq 2
      (0...ary.size).bsearch { |i| ary[i] >= 8 }.should eq 3
      (0...ary.size).bsearch { |i| ary[i] >= 10 }.should eq 4
      (0...ary.size).bsearch { |i| ary[i] >= 100 }.should eq nil
      (0...ary.size).bsearch { |i| true }.should eq 0
      (0...ary.size).bsearch { |i| false }.should eq nil

      ary = [0, 100, 100, 100, 200]
      (0...ary.size).bsearch { |i| ary[i] >= 100 }.should eq 1

      (0_i8..10_i8).bsearch { |x| x >= 10 }.should eq 10_i8
      (0_i8...10_i8).bsearch { |x| x >= 10 }.should eq nil
      (-10_i8...10_i8).bsearch { |x| x >= -5 }.should eq -5_i8

      (0_u8..10_u8).bsearch { |x| x >= 10 }.should eq 10_u8
      (0_u8...10_u8).bsearch { |x| x >= 10 }.should eq nil
      (0_u32..10_u32).bsearch { |x| x >= 10 }.should eq 10_u32
      (0_u32...10_u32).bsearch { |x| x >= 10 }.should eq nil

      (BigInt.new("-10")...BigInt.new("10")).bsearch { |x| x >= -5 }.should eq BigInt.new("-5")
    end

    it "Float" do
      inf = Float64::INFINITY
      (0.0...100.0).bsearch { |x| x > 0 && Math.log(x / 10) >= 0 }.not_nil!.should be_close(10.0, 0.0001)
      (0.0...inf).bsearch { |x| x > 0 && Math.log(x / 10) >= 0 }.not_nil!.should be_close(10.0, 0.0001)
      (-inf..100.0).bsearch { |x| x >= 0 || Math.log(-x / 10) < 0 }.not_nil!.should be_close(-10.0, 0.0001)
      (-inf..inf).bsearch { |x| x > 0 && Math.log(x / 10) >= 0 }.not_nil!.should be_close(10.0, 0.0001)
      (-inf..5).bsearch { |x| x > 0 && Math.log(x / 10) >= 0 }.should be_nil

      (-inf..10).bsearch { |x| x > 0 && Math.log(x / 10) >= 0 }.not_nil!.should be_close(10.0, 0.0001)
      (inf...10).bsearch { |x| x > 0 && Math.log(x / 10) >= 0 }.should be_nil

      (-inf..inf).bsearch { false }.should be_nil
      (-inf..inf).bsearch { true }.should eq -inf

      (0..inf).bsearch { |x| x == inf }.should eq inf
      (0...inf).bsearch { |x| x == inf }.should be_nil

      v = (0.0..1.0).bsearch { |x| x > 0 }.not_nil!
      v.should be_close(0, 0.0001)
      (0 < v).should be_true

      (-1.0..0.0).bsearch { |x| x >= 0 }.should eq 0.0
      (-1.0...0.0).bsearch { |x| x >= 0 }.should be_nil

      (0.0..inf).bsearch { |x| Math.log(x) >= 0 }.not_nil!.should be_close(1.0, 0.0001)

      (0.0..10).bsearch { |x| x >= 3.5 }.not_nil!.should be_close(3.5, 0.0001)
      (0..10.0).bsearch { |x| x >= 3.5 }.not_nil!.should be_close(3.5, 0.0001)

      (0_f32..5_f32).bsearch { |x| x >= 5_f32 }.not_nil!.should be_close(5_f32, 0.0001_f32)
      (0_f32...5_f32).bsearch { |x| x >= 5_f32 }.should be_nil
      (0_f32..5.0).bsearch { |x| x >= 5.0 }.not_nil!.should be_close(5.0, 0.0001)
      (0..5.0_f32).bsearch { |x| x >= 5.0 }.not_nil!.should be_close(5.0, 0.0001)

      inf32 = Float32::INFINITY
      (0..inf32).bsearch { |x| x == inf32 }.should eq inf32
      (0_f32..inf).bsearch { |x| x == inf }.should eq inf
      (0.0..inf32).bsearch { |x| x == inf32 }.should eq inf32
      (0_f32...5_f32).bsearch { |x| x >= 5_f32 }.should be_nil
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

  describe "reverse_each iterator" do
    it "does next with inclusive range" do
      a = 1..3
      iter = a.reverse_each
      iter.next.should eq(3)
      iter.next.should eq(2)
      iter.next.should eq(1)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(3)
    end

    it "does next with exclusive range" do
      r = 1...3
      iter = r.reverse_each
      iter.next.should eq(2)
      iter.next.should eq(1)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(2)
    end

    it "reverse cycles" do
      (1..3).reverse_each.cycle.first(8).join.should eq("32132132")
    end

    it "is empty with .. and begin > end" do
      (1..0).reverse_each.to_a.empty?.should be_true
    end

    it "is empty with ... and begin > end" do
      (1...0).reverse_each.to_a.empty?.should be_true
    end

    it "is not empty with .. and begin == end" do
      (1..1).reverse_each.to_a.should eq([1])
    end

    it "is not empty with ... and begin.succ == end" do
      (1...2).reverse_each.to_a.should eq([1])
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

  describe "map" do
    it "optimizes for int range" do
      (5..12).map(&.itself).should eq([5, 6, 7, 8, 9, 10, 11, 12])
      (5...12).map(&.itself).should eq([5, 6, 7, 8, 9, 10, 11])
      (5..4).map(&.itself).size.should eq(0)
    end

    it "works for other types" do
      ('a'..'c').map(&.itself).should eq(['a', 'b', 'c'])
    end
  end

  describe "size" do
    it "optimizes for int range" do
      (5..12).size.should eq(8)
      (5...12).size.should eq(7)
      (5..4).size.should eq(0)
    end

    it "works for other types" do
      ('a'..'c').size.should eq(3)
    end
  end

  it "clones" do
    range = [1]..[2]
    clone = range.clone
    clone.should eq(range)
    clone.begin.should_not be(range.begin)
    clone.end.should_not be(range.end)
  end
end
