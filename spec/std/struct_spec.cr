require "spec"
require "big_int"

private module StructSpec
  struct TestClass
    @x : Int32
    @y : String

    def initialize(@x, @y)
    end
  end

  struct BigIntWrapper
    @value : BigInt

    def initialize(@value : BigInt)
    end
  end

  struct DupCloneStruct
    property x, y

    def initialize
      @x = 1
      @y = [1, 2, 3]
    end

    def_clone
  end
end

describe "Struct" do
  it "does to_s" do
    s = StructSpec::TestClass.new(1, "hello")
    s.to_s.should eq(%(StructSpec::TestClass(@x=1, @y="hello")))
  end

  it "does ==" do
    s = StructSpec::TestClass.new(1, "hello")
    s.should eq(s)
  end

  it "does hash" do
    s = StructSpec::TestClass.new(1, "hello")
    s.hash.should eq(s.dup.hash)
  end

  it "does hash for struct wrapper (#1940)" do
    s = StructSpec::BigIntWrapper.new(BigInt.new(0))
    s.hash.should eq(s.dup.hash)
  end

  it "does dup" do
    original = StructSpec::DupCloneStruct.new
    duplicate = original.dup
    duplicate.x.should eq(original.x)
    duplicate.y.should be(original.y)

    original.x = 10
    duplicate.x.should_not eq(10)
  end

  it "clones with def_clone" do
    original = StructSpec::DupCloneStruct.new
    clone = original.clone
    clone.x.should eq(original.x)
    clone.y.should_not be(original.y)
    clone.y.should eq(original.y)

    original.x = 10
    clone.x.should_not eq(10)
  end
end
