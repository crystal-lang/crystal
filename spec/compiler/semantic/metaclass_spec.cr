require "../../spec_helper"

describe "Semantic: metaclass" do
  it "types Object class" do
    assert_type("Object") { program.object.metaclass }
  end

  it "types Class class" do
    assert_type("Class") { class_type }
  end

  it "types Object and Class metaclasses" do
    assert_type("Object.class") { class_type }
    assert_type("Class.class") { class_type }
  end

  it "types Reference metaclass" do
    assert_type("Reference") { program.reference.metaclass }
    assert_type("Reference.class") { class_type }
  end

  it "types generic class metaclass" do
    assert_type("Pointer") { pointer.metaclass }
    assert_type("Pointer.class") { class_type }
    assert_type("Pointer(Int32)") { pointer_of(int32).metaclass }
    assert_type("Pointer(Int32).class") { class_type }
  end

  it "types generic module metaclass" do
    assert_type("module Foo(T); end; Foo") { types["Foo"].metaclass }
    assert_type("module Foo(T); end; Foo.class") { class_type }
    assert_type("module Foo(T); end; Foo(Int32)") { generic_module("Foo", int32).metaclass }
    assert_type("module Foo(T); end; Foo(Int32).class") { class_type }
  end

  it "types metaclass parent" do
    input = parse("
      class Foo; end
      class Bar < Foo; end
    ")
    result = semantic input
    mod = result.program

    mod.types["Bar"].metaclass.as(ClassType).superclass.should eq(mod.types["Foo"].metaclass)
  end
end
