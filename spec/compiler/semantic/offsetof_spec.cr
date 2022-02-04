require "../../spec_helper"

describe "Semantic: offsetof" do
  it "types offsetof" do
    assert_type("offsetof(String, @length)") { int32 }
    assert_type("offsetof({Int32, Int32}, 1)") { int32 }
  end

  it "can be used with generic types" do
    assert_type("struct Foo(T); @a : T = 0; end; offsetof(Foo(Int32), @a)") { int32 }
  end

  it "can be used with classes" do
    assert_type("class Foo; @a = 0; end; offsetof(Foo, @a)") { int32 }
  end

  it "errors on undefined instance variable" do
    assert_error "struct Foo; @a = 0; end; offsetof(Foo, @b)", "type Foo doesn't have an instance variable called @b"
  end

  it "errors on typeof inside offsetof expression" do
    assert_error "struct Foo; @a = 0; end; foo = Foo.new; offsetof(typeof(foo), @a)", "can't use typeof inside offsetof expression"
  end

  it "gives error if using offsetof on something that can't have instance variables" do
    assert_error "offsetof(Int32, @foo)", "type Int32 can't have instance variables"
  end

  it "gives error if using offsetof on something that's neither a class, a struct nor a Tuple" do
    assert_error "module Foo; @a = 0; end; offsetof(Foo, @a)", "Foo is neither a class, a struct nor a Tuple, it's a module"
  end

  it "errors on offsetof element of uninstantiated generic type" do
    assert_error "struct Foo(T); @a = 0; end; offsetof(Foo, @a)", "can't take offsetof element @a of uninstantiated generic type Foo(T)"
  end

  it "gives error if using offsetof on Tuples with negative indexes" do
    assert_error "offsetof({Int32,UInt8}, -3)", "can't take a negative offset of a tuple"
  end

  it "gives error if using offsetof on Tuples with indexes greater than tuple size" do
    assert_error "offsetof({Int32,UInt8}, 2)", "can't take offset element at index 2 from a tuple with 2 elements"
    assert_error "offsetof({Int32,UInt8}, 3)", "can't take offset element at index 3 from a tuple with 2 elements"
  end

  it "gives error if using offsetof on Tuples with instance variables" do
    assert_error "offsetof({Int32,UInt8}, @a)", "can't take offset of a tuple element using an instance variable, use an index"
  end

  it "gives error if using offsetof on non-Tuples with an index" do
    assert_error "class Foo; @a = 0; end; offsetof(Foo, 0)", "can't take offset element of Foo using an index, use an instance variable"
  end
end
