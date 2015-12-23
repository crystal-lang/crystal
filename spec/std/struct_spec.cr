require "spec"
require "big_int"

struct StructSpecTestClass
  def initialize(@x, @y)
  end
end

struct StructSpecBigIntWrapper
  def initialize(@value : BigInt)
  end
end

describe "Struct" do
  it "does to_s" do
    s = StructSpecTestClass.new(1, "hello")
    s.to_s.should eq(%(StructSpecTestClass(@x=1, @y="hello")))
  end

  it "does ==" do
    s = StructSpecTestClass.new(1, "hello")
    s.should eq(s)
  end

  it "does hash" do
    s = StructSpecTestClass.new(1, "hello")
    s.hash.should eq(31 + "hello".hash)
  end

  it "does hash for struct wrapper (#1940)" do
    StructSpecBigIntWrapper.new(BigInt.new(0)).hash.should eq(0)
  end
end
