require "spec"
require "enumerator"

describe Enumerator do
  it "creates enumerator" do
    iter = Enumerator(Int32).new do |y|
      y << 1
      y << 2
      y << 3
    end
    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should eq(3)
    iter.next.should be_a(Iterator::Stop)
  end
end
