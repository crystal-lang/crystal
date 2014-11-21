require "spec"

struct StructSpecTestClass
  def initialize(@x, @y)
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
end
