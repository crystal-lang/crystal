require "spec"

private class ComparableTestClass
  include Comparable(Int)

  def initialize(@value : Int32)
  end

  def <=>(other : Int)
    @value <=> other
  end
end

describe Comparable do
  it "can compare against Int (#2461)" do
    obj = ComparableTestClass.new(4)
    (obj == 3).should be_false
    (obj < 3).should be_false
    (obj > 3).should be_true
  end
end
