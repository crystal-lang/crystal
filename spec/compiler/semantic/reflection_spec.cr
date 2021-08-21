require "../../spec_helper"

describe "Semantic: reflection" do
  it "types Object class" do
    assert_type("Object") { types["Object"].metaclass }
  end

  it "types Class class" do
    assert_type("Class") { types["Class"] }
  end

  it "types Object and Class metaclasses" do
    assert_type("Object.class") { types["Class"] }
    assert_type("Class.class") { types["Class"] }
  end

  it "types Reference metaclass" do
    assert_type("Reference") { types["Reference"].metaclass }
    assert_type("Reference.class") { types["Class"] }
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

  it "doesn't put Object.class as the parent of generic module instance metaclasses (#11110)" do
    mod = semantic(%(
      module Foo(T); end
      )).program

    foo_int32_class = mod.generic_module("Foo", mod.int32).metaclass
    foo_int32_class.parents.should eq([mod.class_type])
    foo_int32_class.ancestors.should eq([mod.class_type, mod.value, mod.object])
  end
end
