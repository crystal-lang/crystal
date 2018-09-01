require "spec"

private class SafeIndexable
  include Indexable(Int32)

  property size

  def initialize(@size : Int32)
  end

  def unsafe_at(i)
    raise IndexError.new unless 0 <= i < size
    i
  end
end

private class SafeStringIndexable
  include Indexable(String)

  property size

  def initialize(@size : Int32)
  end

  def unsafe_at(i)
    raise IndexError.new unless 0 <= i < size
    i.to_s
  end
end

private class SafeMixedIndexable
  include Indexable(String | Int32)

  property size

  def initialize(@size : Int32)
  end

  def unsafe_at(i)
    raise IndexError.new unless 0 <= i < size
    i.to_s
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
end
