require "spec"
require "../support/finalize"

private module ReferenceSpec
  class TestClass
    @x : Int32
    @y : String

    def initialize(@x, @y)
    end
  end

  class TestClassBase
  end

  class TestClassSubclass < TestClassBase
  end

  class DupCloneClass
    getter x, y

    def initialize
      @x = 1
      @y = "y"
    end

    def_clone
  end

  class DupCloneRecursiveClass
    getter x, y, z

    def initialize
      @x = 1
      @y = [1, 2, 3]
      @z = self
    end

    def_clone
  end

  abstract class Abstract
  end

  class Concrete < Abstract
    property x

    def initialize(@x : Int32)
    end
  end

  class TestClassWithFinalize
    include FinalizeCounter
  end

  class NestedErrorTestClass
    @x = RaisesOnInspectAndClone.new

    def_clone
  end

  class RaisesOnInspectAndClone
    def inspect(io : IO)
      raise RuntimeError.new("I'm shy")
    end

    def clone
      raise RuntimeError.new("I'm unique")
    end
  end
end

private def expect_empty_recursive_hashes
  Fiber.current.exec_recursive_hash.dup.should be_empty
  Fiber.current.exec_recursive_clone_hash.dup.should be_empty
ensure
  Fiber.current.exec_recursive_clone_hash.clear
  Fiber.current.exec_recursive_hash.clear
end

describe "Reference" do
  it "compares reference to other reference" do
    o1 = Reference.new
    o2 = Reference.new
    (o1 == o1).should be_true
    (o1 == o2).should be_false
    (o1 == 1).should be_false
  end

  it "should not be nil" do
    Reference.new.nil?.should be_false
  end

  it "should be false when negated" do
    (!Reference.new).should be_false
  end

  describe "#inspect" do
    it "does inspect" do
      r = ReferenceSpec::TestClass.new(1, "hello")
      r.inspect.should eq(%(#<ReferenceSpec::TestClass:0x#{r.object_id.to_s(16)} @x=1, @y="hello">))
      expect_empty_recursive_hashes
    end

    it "does inspect for class" do
      String.inspect.should eq("String")
      expect_empty_recursive_hashes
    end

    it "handles error" do
      r = ReferenceSpec::NestedErrorTestClass.new
      expect_raises RuntimeError, "I'm shy" do
        r.inspect
      end
      expect_empty_recursive_hashes
    end
  end

  describe "#to_s" do
    it "does to_s" do
      r = ReferenceSpec::TestClass.new(1, "hello")
      r.to_s.should eq(%(#<ReferenceSpec::TestClass:0x#{r.object_id.to_s(16)}>))
    end

    it "does to_s for class" do
      String.to_s.should eq("String")
    end

    it "does to_s for class if virtual" do
      [ReferenceSpec::TestClassBase, ReferenceSpec::TestClassSubclass].to_s.should eq("[ReferenceSpec::TestClassBase, ReferenceSpec::TestClassSubclass]")
    end
  end

  it "returns itself" do
    x = "hello"
    x.itself.should be(x)
  end

  describe "#dup" do
    it "dups" do
      original = ReferenceSpec::DupCloneClass.new
      duplicate = original.dup
      duplicate.should_not be(original)
      duplicate.x.should eq(original.x)
      duplicate.y.should be(original.y)
    end

    it "can dup class that inherits abstract class" do
      original = ReferenceSpec::Concrete.new(2).as(ReferenceSpec::Abstract)
      duplicate = original.dup
      duplicate.should be_a(ReferenceSpec::Concrete)
      duplicate.should_not be(original)
      duplicate.x.should eq(original.x)
    end

    it "calls #finalize on #dup'ed objects" do
      obj = ReferenceSpec::TestClassWithFinalize.new
      assert_finalizes("dup") { obj.dup }
    end
  end

  describe "#clone" do
    it "clones with def_clone" do
      original = ReferenceSpec::DupCloneClass.new
      clone = original.clone
      clone.should_not be(original)
      clone.x.should eq(original.x)
      expect_empty_recursive_hashes
    end

    it "clones with def_clone (recursive type)" do
      original = ReferenceSpec::DupCloneRecursiveClass.new
      clone = original.clone
      clone.should_not be(original)
      clone.x.should eq(original.x)
      clone.y.should_not be(original.y)
      clone.y.should eq(original.y)
      clone.z.should be(clone)
      expect_empty_recursive_hashes
    end

    it "handles error" do
      r = ReferenceSpec::NestedErrorTestClass.new
      expect_raises RuntimeError, "I'm unique" do
        r.clone
      end
      expect_empty_recursive_hashes
    end
  end

  it "pretty_print" do
    ReferenceSpec::TestClassBase.new.pretty_inspect.should match(/\A#<ReferenceSpec::TestClassBase:0x[0-9a-f]+>\Z/)
    ReferenceSpec::TestClass.new(42, "foo").pretty_inspect.should match(/\A#<ReferenceSpec::TestClass:0x[0-9a-f]+ @x=42, @y="foo">\Z/)
    expect_empty_recursive_hashes
  end
end
