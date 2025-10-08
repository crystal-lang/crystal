require "spec"

private struct Foo
  getter i : Int64
  getter str = "abc"

  def initialize(@i)
  end

  def initialize(@str, @i)
  end
end

private struct Bar
  getter x : UInt8[128]

  def initialize(@x)
  end
end

private struct Inner
end

private struct Outer
  @x = Inner.new
end

describe "Primitives: struct" do
  describe ".pre_initialize" do
    it "doesn't fail on complex ivar initializer if value is discarded (#14325)" do
      bar = uninitialized Outer
      Outer.pre_initialize(pointerof(bar))
      1
    end

    it "zeroes the instance data" do
      bar = uninitialized Bar
      Slice.new(pointerof(bar).as(UInt8*), sizeof(Bar)).fill(0xFF)
      Bar.pre_initialize(pointerof(bar))
      bar.x.all?(&.zero?).should be_true
    end

    it "runs inline instance initializers" do
      foo = uninitialized Foo
      Foo.pre_initialize(pointerof(foo)).should be_nil
      foo.str.should eq("abc")
    end

    it "works when address is on the heap" do
      foo_buffer = Pointer(Foo).malloc(1)
      Foo.pre_initialize(foo_buffer)
      foo_buffer.value.str.should eq("abc")
    end
  end
end
