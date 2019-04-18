require "spec"

private class ComparableTestClass
  include Comparable(Int)

  def initialize(@value : Int32, @return_nil = false)
  end

  def <=>(other : Int)
    return nil if @return_nil

    @value <=> other
  end
end

describe Comparable do
  it "can compare against Int (#2461)" do
    obj = ComparableTestClass.new(4)
    (obj == 3).should be_false
    (obj == 4).should be_true

    (obj < 3).should be_false
    (obj < 4).should be_false

    (obj > 3).should be_true
    (obj > 4).should be_false

    (obj <= 3).should be_false
    (obj <= 4).should be_true
    (obj <= 5).should be_true

    (obj >= 3).should be_true
    (obj >= 4).should be_true
    (obj >= 5).should be_false
  end

  it "checks for nil" do
    obj = ComparableTestClass.new(4, return_nil: true)

    (obj < 1).should be_false
    (obj <= 1).should be_false
    (obj == 1).should be_false
    (obj >= 1).should be_false
    (obj > 1).should be_false
  end
end
