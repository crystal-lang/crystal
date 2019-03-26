require "../../spec_helper"

describe "Semantic: offsetof" do
  it "types offsetof" do
    assert_type("offsetof(String, @length)") { int32 }
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

  it "gives error if using offsetof on something that's neither a class nor a struct" do
    assert_error "module Foo; @a = 0; end; offsetof(Foo, @a)", "Foo is neither a class nor a struct, it's a module"
  end

  it "errors on offsetof element of uninstantiated generic type" do
    assert_error "struct Foo(T); @a = 0; end; offsetof(Foo, @a)", "can't take offsetof element @a of uninstantiated generic type Foo(T)"
  end
end
