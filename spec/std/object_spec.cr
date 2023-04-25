require "spec"
require "../support/finalize"

private class StringWrapper
  delegate downcase, to: @string
  delegate upcase, capitalize, char_at, scan, to: @string

  @string : String

  def initialize(@string)
  end
end

private class TestObject
  getter getter1
  getter getter2 : Int32
  getter getter3 : Int32 = 3
  getter getter4 = 4

  getter! getter5
  @getter5 : Int32?

  getter! getter6 : Int32

  getter? getter7
  getter? getter8 : Bool
  getter? getter9 : Bool = true
  getter? getter10 = true

  getter(getter11) { 11 }

  @@getter12_value = 12
  getter getter12 : Int32 { @@getter12_value }

  def self.getter12_value=(@@getter12_value)
  end

  @getter13_counter = 0
  getter(getter13) { @getter13_counter += 1; false }

  getter?(getter14 : Bool) { true }
  getter?(getter15) { true }

  setter setter1
  setter setter2 : Int32
  setter setter3 : Int32 = 3
  setter setter4 = 4

  property property1
  property property2 : Int32
  property property3 : Int32 = 3
  property property4 = 4

  property! property5
  @property5 : Int32?

  property! property6 : Int32

  property? property7
  property? property8 : Bool
  property? property9 : Bool = true
  property? property10 = true

  property(property11) { 11 }
  property property12 : Int32 { 10 + 2 }

  @property13_counter = 0
  property(property13) { @property13_counter += 1; false }

  property?(property14 : Bool) { true }
  property?(property15) { true }

  def initialize
    @getter1 = 1
    @getter2 = 2

    @getter7 = true
    @getter8 = true

    @setter1 = 1
    @setter2 = 2

    @property1 = 1
    @property2 = 2

    @property7 = true
    @property8 = true
  end

  def getter5=(@getter5)
  end

  def getter6=(@getter6)
  end

  def setter1
    @setter1
  end

  def setter2
    @setter2
  end

  def setter3
    @setter3
  end

  def setter4
    @setter4
  end

  def []=(key, value)
    {key, value}
  end

  annotation TestAnnotation
  end

  @[TestAnnotation]
  property(x : Int32) { 1 }

  def self.test_annotation_count
    {{ @type.instance_vars.select(&.annotation(TestObject::TestAnnotation)).size }}
  end

  def self.do_set_crystal_type_id(ptr)
    set_crystal_type_id(ptr)
  end
end

private class DelegatedTestObject
  delegate :property1=, to: @test_object
  delegate :[]=, to: @test_object

  def initialize(@test_object : TestObject)
  end
end

private class TestObjectWithFinalize
  include FinalizeCounter

  def_clone
end

private class HashedTestObject
  property a : Int32
  property b : Int32

  def initialize(@a, @b)
  end

  def_hash :a, :b
end

private struct NonReflexive
  def ==(other)
    false
  end
end

private class DefEquals
  def initialize
    @x = NonReflexive.new
  end

  def_equals @x
end

private struct TestMutableStruct
  getter x = 0

  def foo
    @x += 1
  end
end

describe Object do
  describe "delegate" do
    it "delegates" do
      wrapper = StringWrapper.new("HellO")
      wrapper.downcase.should eq("hello")
      wrapper.upcase.should eq("HELLO")
      wrapper.capitalize.should eq("Hello")

      wrapper.char_at(0).should eq('H')
      wrapper.char_at(index: 1).should eq('e')

      wrapper.char_at(10) { 20 }.should eq(20)

      matches = [] of String
      wrapper.scan(/l/) do |match|
        matches << match[0]
      end
      matches.should eq(["l", "l"])
    end

    it "delegates setter" do
      test_object = TestObject.new
      delegated = DelegatedTestObject.new(test_object)
      delegated.property1 = 42
      test_object.property1.should eq 42
    end

    it "delegates []=" do
      test_object = TestObject.new
      delegated = DelegatedTestObject.new(test_object)
      (delegated["foo"] = "bar").should eq({"foo", "bar"})
    end
  end

  describe "getter" do
    it "uses simple getter" do
      obj = TestObject.new
      obj.getter1.should eq(1)
      typeof(obj.@getter1).should eq(Int32)
      typeof(obj.getter1).should eq(Int32)
    end

    it "uses getter with type declaration" do
      obj = TestObject.new
      obj.getter2.should eq(2)
      typeof(obj.@getter2).should eq(Int32)
      typeof(obj.getter2).should eq(Int32)
    end

    it "uses getter with type declaration and default value" do
      obj = TestObject.new
      obj.getter3.should eq(3)
      typeof(obj.@getter3).should eq(Int32)
      typeof(obj.getter3).should eq(Int32)
    end

    it "uses getter with assignment" do
      obj = TestObject.new
      obj.getter4.should eq(4)
      typeof(obj.@getter4).should eq(Int32)
      typeof(obj.getter4).should eq(Int32)
    end

    it "defines lazy getter with block" do
      obj = TestObject.new
      obj.getter11.should eq(11)
      obj.getter12.should eq(12)
      TestObject.getter12_value = 24
      obj.getter12.should eq(12)

      obj2 = TestObject.new
      obj2.getter12.should eq(24)
    end

    it "defines lazy getter with block returning false" do
      obj = TestObject.new
      obj.@getter13_counter.should eq(0)
      3.times { obj.getter13.should be_false }
      obj.@getter13_counter.should eq(1)
    end
  end

  describe "getter!" do
    it "uses getter!" do
      obj = TestObject.new
      expect_raises(NilAssertionError, "TestObject#getter5 cannot be nil") do
        obj.getter5
      end
      obj.getter5 = 5
      obj.getter5.should eq(5)
      typeof(obj.@getter5).should eq(Int32 | Nil)
      typeof(obj.getter5).should eq(Int32)
    end

    it "uses getter! with type declaration" do
      obj = TestObject.new
      expect_raises(NilAssertionError, "TestObject#getter6 cannot be nil") do
        obj.getter6
      end
      obj.getter6 = 6
      obj.getter6.should eq(6)
      typeof(obj.@getter6).should eq(Int32 | Nil)
      typeof(obj.getter6).should eq(Int32)
    end
  end

  describe "getter?" do
    it "uses getter?" do
      obj = TestObject.new
      obj.getter7?.should be_true
      typeof(obj.@getter7).should eq(Bool)
      typeof(obj.getter7?).should eq(Bool)
    end

    it "uses getter? with type declaration" do
      obj = TestObject.new
      obj.getter8?.should be_true
      typeof(obj.@getter8).should eq(Bool)
      typeof(obj.getter8?).should eq(Bool)
    end

    it "uses getter? with type declaration and default value" do
      obj = TestObject.new
      obj.getter9?.should be_true
      typeof(obj.@getter9).should eq(Bool)
      typeof(obj.getter9?).should eq(Bool)
    end

    it "uses getter? with default value" do
      obj = TestObject.new
      obj.getter10?.should be_true
      typeof(obj.@getter10).should eq(Bool)
      typeof(obj.getter10?).should eq(Bool)
    end

    it "uses getter? with type declaration and block" do
      obj = TestObject.new
      typeof(obj.@getter14).should eq(Bool?)
      typeof(obj.getter14?).should eq(Bool)
      obj.@getter14.should be_nil
      obj.getter14?.should be_true
      obj.@getter14.should be_true
    end

    it "uses getter? with block" do
      obj = TestObject.new
      typeof(obj.@getter15).should eq(Bool?)
      typeof(obj.getter15?).should eq(Bool)
      obj.@getter15.should be_nil
      obj.getter15?.should be_true
      obj.@getter15.should be_true
    end
  end

  describe "setter" do
    it "uses setter" do
      obj = TestObject.new
      obj.setter1.should eq(1)
      obj.setter1 = 2
      obj.setter1.should eq(2)
    end

    it "uses setter with type declaration" do
      obj = TestObject.new
      obj.setter2.should eq(2)
      obj.setter2 = 3
      obj.setter2.should eq(3)
    end

    it "uses setter with type declaration and default value" do
      obj = TestObject.new
      obj.setter3.should eq(3)
      obj.setter3 = 4
      obj.setter3.should eq(4)
    end

    it "uses setter with default value" do
      obj = TestObject.new
      obj.setter4.should eq(4)
      obj.setter4 = 5
      obj.setter4.should eq(5)
    end
  end

  describe "property" do
    it "uses property" do
      obj = TestObject.new
      obj.property1.should eq(1)
      obj.property1 = 2
      obj.property1.should eq(2)
    end

    it "uses property with type declaration" do
      obj = TestObject.new
      obj.property2.should eq(2)
      obj.property2 = 3
      obj.property2.should eq(3)
    end

    it "uses property with type declaration and default value" do
      obj = TestObject.new
      obj.property3.should eq(3)
      obj.property3 = 4
      obj.property3.should eq(4)
    end

    it "uses property with default value" do
      obj = TestObject.new
      obj.property4.should eq(4)
      obj.property4 = 5
      obj.property4.should eq(5)
    end

    it "defines lazy property with block" do
      obj = TestObject.new
      obj.property11.should eq(11)
      obj.property11 = 12
      obj.property11.should eq(12)

      obj.property12.should eq(12)
      obj.property12 = 13
      obj.property12.should eq(13)
    end

    it "defines lazy property with block returning false" do
      obj = TestObject.new
      obj.@property13_counter.should eq(0)
      3.times { obj.property13.should be_false }
      obj.@property13_counter.should eq(1)
    end
  end

  describe "property!" do
    it "uses property!" do
      obj = TestObject.new
      expect_raises(NilAssertionError, "TestObject#property5 cannot be nil") do
        obj.property5
      end
      obj.property5 = 5
      obj.property5.should eq(5)
    end

    it "uses property! with type declaration" do
      obj = TestObject.new
      expect_raises(NilAssertionError, "TestObject#property6 cannot be nil") do
        obj.property6
      end
      obj.property6 = 6
      obj.property6.should eq(6)
    end
  end

  describe "property?" do
    it "uses property?" do
      obj = TestObject.new
      obj.property7?.should be_true
      obj.property7 = false
      obj.property7?.should be_false
    end

    it "uses property? with type declaration" do
      obj = TestObject.new
      obj.property8?.should be_true
      obj.property8 = false
      obj.property8?.should be_false
    end

    it "uses property? with type declaration and default value" do
      obj = TestObject.new
      obj.property9?.should be_true
      obj.property9 = false
      obj.property9?.should be_false
    end

    it "uses property? with default value" do
      obj = TestObject.new
      obj.property10?.should be_true
      obj.property10 = false
      obj.property10?.should be_false
    end

    it "uses property? with type declaration and block" do
      obj = TestObject.new
      typeof(obj.@property14).should eq(Bool?)
      typeof(obj.property14?).should eq(Bool)
      obj.@property14.should be_nil
      obj.property14?.should be_true
      obj.@property14.should be_true
    end

    it "uses property? with block" do
      obj = TestObject.new
      typeof(obj.@property15).should eq(Bool?)
      typeof(obj.property15?).should eq(Bool)
      obj.@property15.should be_nil
      obj.property15?.should be_true
      obj.@property15.should be_true
    end
  end

  describe "#in?" do
    it "works with Enumerable-s" do
      "foo".in?(["foo", "bar"]).should be_true
      "bar".in?({"foo", "baz"}).should be_false
      42.in?(0..100).should be_true
      4242.in?(0..100).should be_false
    end

    it "works with splatted arguments" do
      "baz".in?("foo", "bar").should be_false
      1.in?(1, 10, 100).should be_true
    end

    it "works with other objects implementing #includes?" do
      "o".in?("foo").should be_true
      'o'.in?("foo").should be_true
      'x'.in?("foo").should be_false
    end
  end

  it "#unsafe_as" do
    0x12345678.unsafe_as(Tuple(UInt8, UInt8, UInt8, UInt8)).should eq({0x78, 0x56, 0x34, 0x12})
  end

  it "calls #finalize on #clone'd objects" do
    obj = TestObjectWithFinalize.new
    assert_finalizes("clone") { obj.clone }
  end

  describe "def_hash" do
    it "should return same hash for equal property values" do
      HashedTestObject.new(1, 2).hash.should eq HashedTestObject.new(1, 2).hash
    end

    it "shouldn't return same hash for different property values" do
      HashedTestObject.new(1, 2).hash.should_not eq HashedTestObject.new(3, 4).hash
    end
  end

  it "applies annotation to lazy property (#9139)" do
    TestObject.test_annotation_count.should eq(1)
  end

  describe "def_equals" do
    it "compares by reference" do
      x = DefEquals.new
      y = DefEquals.new
      (x == x).should be_true
      (x == y).should be_false
    end
  end

  describe "#not_nil!" do
    it "basic" do
      1.not_nil!
      expect_raises(NilAssertionError, "Nil assertion failed") do
        nil.not_nil!
      end
    end

    it "removes Nil type" do
      x = TestObject.new.as(TestObject?)
      typeof(x.not_nil!).should eq TestObject
      x.not_nil!.should be x
    end

    it "raises NilAssertionError" do
      x = nil.as(TestObject?)
      typeof(x.not_nil!).should eq TestObject
      expect_raises(NilAssertionError, "Nil assertion failed") do
        x.not_nil!
      end
    end

    it "with message" do
      x = TestObject.new
      x.not_nil!("custom message").should be x
      expect_raises(NilAssertionError, "custom message") do
        nil.not_nil!("custom message")
      end
    end

    it "does not copy its receiver when it is a value (#13263)" do
      x = TestMutableStruct.new
      x.not_nil!.foo.should eq(1)
      x.not_nil!.foo.should eq(2)
      x.foo.should eq(3)
    end
  end

  it ".set_crystal_type_id" do
    ary = StaticArray[Int32::MAX, Int32::MAX]
    TestObject.do_set_crystal_type_id(pointerof(ary))
    ary[0].should eq TestObject.crystal_instance_type_id
    ary[1].should eq Int32::MAX
  end
end
