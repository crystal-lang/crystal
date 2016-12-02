require "spec"

class SafeIndexable
  include Indexable(Int32)

  getter size

  def initialize(@size : Int32)
  end

  def unsafe_at(i)
    raise IndexError.new unless 0 <= i < size
    i
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
end
