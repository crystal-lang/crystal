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

  it "iterates throught a subset of its elements (#3386)" do
    indexable = SafeIndexable.new(5)
    last_element = nil

    return_value = indexable.each(start: 2, count: 3) do |elem|
      last_element = elem
    end

    return_value.should eq(indexable)
    last_element.should eq(4)
  end

  it "iterates until its size (#3386)" do
    indexable = SafeIndexable.new(5)
    last_element = nil

    indexable.each(start: 3, count: 999) do |elem|
      last_element = elem
    end

    last_element.should eq(4)
  end

  it "iterates until its size, having mutated (#3386)" do
    indexable = SafeIndexable.new(10)
    last_element = nil

    indexable.each(start: 3, count: 999) do |elem|
      indexable.size += 1 if elem <= 5
      # size is incremented 3 times
      last_element = elem
    end

    # last was 9, but now is 12.
    last_element.should eq(12)
  end

  it "iterates until its size, having mutated (#3386)" do
    indexable = SafeIndexable.new(10)
    last_element = nil

    indexable.each(start: 3, count: 5) do |elem|
      indexable.size += 1
      last_element = elem
    end

    # last element iterated is still 7.
    last_element.should eq(7)
  end

  it "iterates within a range of indices (#3386)" do
    indexable = SafeIndexable.new(5)
    last_element = nil

    return_value = indexable.each(within: 2..3) do |elem|
      last_element = elem
    end

    return_value.should eq(indexable)
    last_element.should eq(3)
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
end
