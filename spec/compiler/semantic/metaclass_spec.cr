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

  it "types metaclass superclass" do
    mod = semantic(%(
      class Foo; end
      class Bar < Foo; end
      )).program

    bar_class = mod.types["Bar"].metaclass.should be_a(MetaclassType)
    bar_class.superclass.should eq(mod.types["Foo"].metaclass)
  end

  it "types generic metaclass superclass" do
    mod = semantic(%(
      class Foo(T); end
      class Bar(T) < Foo(T); end
      )).program

    foo_class = mod.types["Foo"].metaclass.as(MetaclassType)
    foo_class.superclass.should eq(mod.program.reference.metaclass)

    bar = mod.types["Bar"].as(GenericClassType)
    bar_class = bar.metaclass.as(MetaclassType)
    bar_class.superclass.should eq(mod.generic_class("Foo", bar.type_parameter("T")).metaclass)
  end

  it "types generic instance metaclass superclass" do
    mod = semantic(%(
      class Foo(T); end
      class Bar(T) < Foo(T); end
      )).program

    foo_class = mod.generic_class("Foo", mod.int32).metaclass.as(GenericClassInstanceMetaclassType)
    foo_class.superclass.should eq(mod.program.reference.metaclass)

    bar_class = mod.generic_class("Bar", mod.int32).metaclass.as(GenericClassInstanceMetaclassType)
    bar_class.superclass.should eq(foo_class)
  end
end
