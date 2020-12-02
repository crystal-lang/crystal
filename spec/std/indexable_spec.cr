require "spec"

private class SafeIndexable
  include Indexable(Int32)

  property size

  def initialize(@size : Int32)
  end

  def unsafe_fetch(i)
    raise IndexError.new unless 0 <= i < size
    i
  end
end

private class SafeNestedIndexable
  include Indexable(Indexable(Int32))

  property size

  def initialize(@size : Int32, @inner_size : Int32)
  end

  def unsafe_fetch(i)
    raise IndexError.new unless 0 <= i < size
    SafeIndexable.new(@inner_size)
  end
end

private class SafeStringIndexable
  include Indexable(String)

  property size

  def initialize(@size : Int32)
  end

  def unsafe_fetch(i)
    raise IndexError.new unless 0 <= i < size
    i.to_s
  end
end

private class SafeMixedIndexable
  include Indexable(String | Int32)

  property size

  def initialize(@size : Int32)
  end

  def unsafe_fetch(i)
    raise IndexError.new unless 0 <= i < size
    i.to_s
  end
end

private class SafeRecursiveIndexable
  include Indexable(SafeRecursiveIndexable | Int32)

  property size

  def initialize(@size : Int32)
  end

  def unsafe_fetch(i)
    raise IndexError.new unless 0 <= i < size
    if (i % 2) == 0
      SafeRecursiveIndexable.new(i)
    else
      i
    end
  end
end

describe Indexable do
  it "does index with big negative offset" do
    indexable = SafeIndexable.new(3)
    indexable.index(0, -100).should be_nil
  end

  it "does index with big offset" do
    indexable = SafeIndexable.new(3)
    indexable.index(0, 100).should be_nil
  end

  it "does rindex with big negative offset" do
    indexable = SafeIndexable.new(3)
    indexable.rindex(0, -100).should be_nil
  end

  it "does rindex with big offset" do
    indexable = SafeIndexable.new(3)
    indexable.rindex(0, 100).should be_nil
  end

  it "does each" do
    indexable = SafeIndexable.new(3)
    is = [] of Int32
    indexable.each do |i|
      is << i
    end.should be_nil
    is.should eq([0, 1, 2])
  end

  it "does each_index" do
    indexable = SafeIndexable.new(3)
    is = [] of Int32
    indexable.each_index do |i|
      is << i
    end.should be_nil
    is.should eq([0, 1, 2])
  end

  it "iterates through a subset of its elements (#3386)" do
    indexable = SafeIndexable.new(5)
    elems = [] of Int32

    return_value = indexable.each(start: 2, count: 3) do |elem|
      elems << elem
    end

    elems.should eq([2, 3, 4])
    return_value.should eq(indexable)
  end

  it "iterates until its size (#3386)" do
    indexable = SafeIndexable.new(5)
    elems = [] of Int32

    indexable.each(start: 3, count: 999) do |elem|
      elems << elem
    end

    elems.should eq([3, 4])
  end

  it "iterates until its size, having mutated (#3386)" do
    indexable = SafeIndexable.new(10)
    elems = [] of Int32

    indexable.each(start: 3, count: 999) do |elem|
      # size is incremented 3 times
      indexable.size += 1 if elem <= 5
      elems << elem
    end

    # last was 9, but now is 12.
    elems.should eq([3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
  end

  it "iterates until its size, having mutated (#3386)" do
    indexable = SafeIndexable.new(10)
    elems = [] of Int32

    indexable.each(start: 3, count: 5) do |elem|
      indexable.size += 1
      elems << elem
    end

    # last element iterated is still 7.
    elems.should eq([3, 4, 5, 6, 7])
  end

  it "iterates within a range of indices (#3386)" do
    indexable = SafeIndexable.new(5)
    elems = [] of Int32

    return_value = indexable.each(within: 2..3) do |elem|
      elems << elem
    end

    elems.should eq([2, 3])
    return_value.should eq(indexable)
  end

  it "iterates within a range of indices, no end" do
    indexable = SafeIndexable.new(5)
    elems = [] of Int32

    return_value = indexable.each(within: 2..nil) do |elem|
      elems << elem
    end

    elems.should eq([2, 3, 4])
    return_value.should eq(indexable)
  end

  it "iterates within a range of indices, no beginning" do
    indexable = SafeIndexable.new(5)

    elems = [] of Int32
    return_value = indexable.each(within: nil..2) do |elem|
      elems << elem
    end

    elems.should eq([0, 1, 2])
    return_value.should eq(indexable)
  end

  it "joins strings (empty case)" do
    indexable = SafeStringIndexable.new(0)
    indexable.join.should eq("")
    indexable.join(", ").should eq("")
  end

  it "joins strings (non-empty case)" do
    indexable = SafeStringIndexable.new(12)
    indexable.join(", ").should eq("0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11")
    indexable.join(98).should eq("098198298398498598698798898998109811")
  end

  it "joins non-strings" do
    indexable = SafeIndexable.new(12)
    indexable.join(", ").should eq("0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11")
    indexable.join(98).should eq("098198298398498598698798898998109811")
  end

  it "joins when T has String" do
    indexable = SafeMixedIndexable.new(12)
    indexable.join(", ").should eq("0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11")
    indexable.join(98).should eq("098198298398498598698798898998109811")
  end

  describe "dig?" do
    it "gets the value at given path given splat" do
      indexable = SafeRecursiveIndexable.new(30)
      indexable.dig?(20, 10, 4, 3).should eq(3)
    end

    it "returns nil if not found" do
      indexable = SafeRecursiveIndexable.new(30)
      indexable.dig?(2, 4).should be_nil
      indexable.dig?(3, 7).should be_nil
    end
  end

  describe "dig" do
    it "gets the value at given path given splat" do
      indexable = SafeRecursiveIndexable.new(30)
      indexable.dig(20, 10, 4, 3).should eq(3)
    end

    it "raises IndexError if not found" do
      indexable = SafeRecursiveIndexable.new(30)
      expect_raises IndexError, %(Index out of bounds) do
        indexable.dig(2, 4)
      end
      expect_raises IndexError, %(Indexable value not diggable for index: 3) do
        indexable.dig(3, 7)
      end
    end
  end

  describe "fetch" do
    it "fetches with default value" do
      indexable = SafeIndexable.new(3)
      a = indexable.to_a

      indexable.fetch(2, 4).should eq(2)
      indexable.fetch(3, 4).should eq(4)
      a.should eq([0, 1, 2])
    end

    it "fetches with block" do
      indexable = SafeIndexable.new(3)
      a = indexable.to_a

      indexable.fetch(2) { |k| k * 3 }.should eq(2)
      indexable.fetch(3) { |k| k * 3 }.should eq(9)
      a.should eq([0, 1, 2])
    end
  end

  describe "#cartesian_product" do
    it "does with 1 other Indexable" do
      elems = SafeIndexable.new(2).cartesian_product(SafeIndexable.new(3))
      elems.should eq([{0, 0}, {0, 1}, {0, 2}, {1, 0}, {1, 1}, {1, 2}])

      elems = SafeIndexable.new(2).cartesian_product(SafeIndexable.new(0))
      elems.empty?.should be_true

      elems = SafeIndexable.new(0).cartesian_product(SafeIndexable.new(3))
      elems.empty?.should be_true
    end

    it "does with >1 other Indexables" do
      elems = SafeIndexable.new(2).cartesian_product(SafeStringIndexable.new(2), SafeIndexable.new(2))
      elems.should eq([
        {0, "0", 0}, {0, "0", 1}, {0, "1", 0}, {0, "1", 1},
        {1, "0", 0}, {1, "0", 1}, {1, "1", 0}, {1, "1", 1},
      ])
    end
  end

  describe ".cartesian_product" do
    it "does with an Indexable of Indexables" do
      elems = Indexable.cartesian_product(SafeNestedIndexable.new(2, 3))
      elems.should eq([[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2], [2, 0], [2, 1], [2, 2]])

      elems = Indexable.cartesian_product(SafeNestedIndexable.new(2, 0))
      elems.empty?.should be_true

      elems = Indexable.cartesian_product(SafeNestedIndexable.new(0, 3))
      elems.empty?.should be_true
    end
  end

  describe "#each_product" do
    it "does with 1 other Indexable, with block" do
      r = [] of Int32 | String
      indexable = SafeIndexable.new(3)
      indexable.each_product(SafeStringIndexable.new(2)) { |a, b| r << a; r << b }
      r.should eq([0, "0", 0, "1", 1, "0", 1, "1", 2, "0", 2, "1"])

      r = [] of Int32 | String
      indexable = SafeIndexable.new(3)
      indexable.each_product(SafeStringIndexable.new(0)) { |a, b| r << a; r << b }
      r.empty?.should be_true

      r = [] of Int32 | String
      indexable = SafeIndexable.new(0)
      indexable.each_product(SafeStringIndexable.new(2)) { |a, b| r << a; r << b }
      r.empty?.should be_true
    end

    it "does with 1 other Indexable, without block" do
      iter = SafeIndexable.new(3).each_product(SafeStringIndexable.new(2))
      iter.next.should eq({0, "0"})
      iter.next.should eq({0, "1"})
      iter.next.should eq({1, "0"})
      iter.next.should eq({1, "1"})
      iter.next.should eq({2, "0"})
      iter.next.should eq({2, "1"})
      iter.next.should be_a(Iterator::Stop)
    end

    it "does with >1 other Indexables, with block" do
      r = [] of Int32 | String
      i1 = SafeIndexable.new(2)
      i2 = SafeIndexable.new(3)
      i3 = SafeIndexable.new(4)
      i1.each_product(i2, i3) { |a, b, c| r << a + b + c }
      r.should eq([0, 1, 2, 3, 1, 2, 3, 4, 2, 3, 4, 5, 1, 2, 3, 4, 2, 3, 4, 5, 3, 4, 5, 6])
    end

    it "does with >1 other Indexables, without block" do
      i1 = SafeStringIndexable.new(2)
      i2 = SafeStringIndexable.new(2)
      i3 = SafeIndexable.new(2)
      iter = i1.each_product(i2, i3)
      iter.next.should eq({"0", "0", 0})
      iter.next.should eq({"0", "0", 1})
      iter.next.should eq({"0", "1", 0})
      iter.next.should eq({"0", "1", 1})
      iter.next.should eq({"1", "0", 0})
      iter.next.should eq({"1", "0", 1})
      iter.next.should eq({"1", "1", 0})
      iter.next.should eq({"1", "1", 1})
      iter.next.should be_a(Iterator::Stop)
    end
  end

  describe ".each_product" do
    it "does with an Indexable of Indexables, with block" do
      r = [] of Int32
      Indexable.each_product(SafeNestedIndexable.new(3, 2)) { |v| r.concat(v) }
      r.should eq([0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1])

      r = [] of Int32
      Indexable.each_product(SafeNestedIndexable.new(0, 2)) { |v| r.concat(v) }
      r.empty?.should be_true

      r = [] of Int32
      Indexable.each_product(SafeNestedIndexable.new(3, 0)) { |v| r.concat(v) }
      r.empty?.should be_true
    end

    it "does with reuse = true, with block" do
      r = [] of Int32
      object_ids = Set(UInt64).new
      indexables = SafeNestedIndexable.new(3, 2)

      Indexable.each_product(indexables, reuse: true) do |v|
        object_ids << v.object_id
        r.concat(v)
      end

      r.should eq([0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1])
      object_ids.size.should eq(1)
    end

    it "does with reuse = array, with block" do
      r = [] of Int32
      buf = [] of Int32
      indexables = SafeNestedIndexable.new(3, 2)

      Indexable.each_product(indexables, reuse: buf) do |v|
        v.should be(buf)
        r.concat(v)
      end

      r.should eq([0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1])
    end

    it "does with an Indexable of Indexables, without block" do
      iter = Indexable.each_product(SafeNestedIndexable.new(2, 3))
      iter.next.should eq([0, 0])
      iter.next.should eq([0, 1])
      iter.next.should eq([0, 2])
      iter.next.should eq([1, 0])
      iter.next.should eq([1, 1])
      iter.next.should eq([1, 2])
      iter.next.should eq([2, 0])
      iter.next.should eq([2, 1])
      iter.next.should eq([2, 2])
      iter.next.should be_a(Iterator::Stop)
    end

    it "does with reuse = true, without block" do
      iter = Indexable.each_product(SafeNestedIndexable.new(2, 2), reuse: true)
      buf = iter.next
      buf.should eq([0, 0])
      iter.next.should be(buf)
      buf.should eq([0, 1])
      iter.next.should be(buf)
      buf.should eq([1, 0])
      iter.next.should be(buf)
      buf.should eq([1, 1])
      iter.next.should be_a(Iterator::Stop)
    end

    it "does with reuse = array, without block" do
      buf = [] of Int32
      iter = Indexable.each_product(SafeNestedIndexable.new(2, 2), reuse: buf)
      iter.next.should be(buf)
      buf.should eq([0, 0])
      iter.next.should be(buf)
      buf.should eq([0, 1])
      iter.next.should be(buf)
      buf.should eq([1, 0])
      iter.next.should be(buf)
      buf.should eq([1, 1])
      iter.next.should be_a(Iterator::Stop)
    end
  end
end
