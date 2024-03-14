require "spec"

private abstract class Base
end

private class Foo < Base
  getter i : Int64
  getter str = "abc"

  def initialize(@i)
  end

  def initialize(@str, @i)
  end
end

private class Bar < Base
  getter x : UInt8[128]

  def initialize(@x)
  end
end

private struct Inner
end

private class Outer
  @x = Inner.new
end

describe "Primitives: reference" do
  describe ".allocate" do
    it "doesn't fail on complex ivar initializer if value is discarded (#14325)" do
      Outer.allocate
      1
    end
  end

  describe ".pre_initialize" do
    it "doesn't fail on complex ivar initializer if value is discarded (#14325)" do
      bar_buffer = GC.malloc(instance_sizeof(Outer))
      Outer.pre_initialize(bar_buffer)
      1
    end

    it "zeroes the instance data" do
      bar_buffer = GC.malloc(instance_sizeof(Bar))
      Slice.new(bar_buffer.as(UInt8*), instance_sizeof(Bar)).fill(0xFF)
      bar = Bar.pre_initialize(bar_buffer)
      bar.x.all?(&.zero?).should be_true
    end

    it "sets type ID" do
      foo_buffer = GC.malloc(instance_sizeof(Foo))
      base = Foo.pre_initialize(foo_buffer).as(Base)
      base.crystal_type_id.should eq(Foo.crystal_instance_type_id)
    end

    it "runs inline instance initializers" do
      foo_buffer = GC.malloc(instance_sizeof(Foo))
      foo = Foo.pre_initialize(foo_buffer)
      foo.str.should eq("abc")
    end

    it "works when address is on the stack" do
      foo_buffer = uninitialized ReferenceStorage(Foo)
      foo = Foo.pre_initialize(pointerof(foo_buffer))
      pointerof(foo_buffer).as(typeof(Foo.crystal_instance_type_id)*).value.should eq(Foo.crystal_instance_type_id)
      foo.str.should eq("abc")
    end

    # see notes in `Reference.pre_initialize`
    {% if compare_versions(Crystal::VERSION, "1.2.0") >= 0 %}
      it "works with virtual type" do
        foo_buffer = GC.malloc(instance_sizeof(Foo))
        foo = Foo.as(Base.class).pre_initialize(foo_buffer).should be_a(Foo)
        foo.str.should eq("abc")
      end
    {% else %}
      pending! "works with virtual type"
    {% end %}

    it "raises on abstract virtual type" do
      expect_raises(Exception, "Can't pre-initialize abstract class Base") do
        Base.as(Base.class).pre_initialize(Pointer(Void).null)
      end
    end
  end

  describe ".unsafe_construct" do
    it "constructs an object in-place" do
      foo_buffer = GC.malloc(instance_sizeof(Foo))
      foo = Foo.unsafe_construct(foo_buffer, 123_i64)
      foo.i.should eq(123)
      foo.str.should eq("abc")

      str = String.build &.<< "def"
      foo = Foo.unsafe_construct(foo_buffer, str, 789_i64)
      foo.i.should eq(789)
      foo.str.should be(str)
    end
  end
end
