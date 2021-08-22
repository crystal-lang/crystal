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

    bar_class = mod.types["Bar"].metaclass.as(MetaclassType)
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

  describe "preserving subtyping relations of instance classes between metaclasses" do
    it "classes" do
      mod = semantic(%(
        class Foo; end
        class Bar < Foo; end
        )).program

      foo_class = mod.types["Foo"].metaclass
      bar_class = mod.types["Bar"].metaclass
      bar_class.implements?(foo_class).should be_true
    end

    it "generic classes (1)" do
      mod = semantic(%(
        class Foo(T); end
        class Bar < Foo(Int32); end
        )).program

      foo_class = mod.types["Foo"].metaclass
      foo_int32_class = mod.generic_class("Foo", mod.int32).metaclass
      bar_class = mod.types["Bar"].metaclass

      bar_class.implements?(foo_int32_class).should be_true
      bar_class.implements?(foo_class).should be_true
      foo_int32_class.implements?(foo_class).should be_true
    end

    it "generic classes (2)" do
      mod = semantic(%(
        class Foo; end
        class Bar(T) < Foo; end
        )).program

      foo_class = mod.types["Foo"].metaclass
      bar_class = mod.types["Bar"].metaclass
      bar_int32_class = mod.generic_class("Bar", mod.int32).metaclass

      bar_int32_class.implements?(bar_class).should be_true
      bar_int32_class.implements?(foo_class).should be_true
      bar_class.implements?(foo_class).should be_true
    end

    it "generic classes (3)" do
      mod = semantic(%(
        class Foo(T); end
        class Bar(T) < Foo(T); end
        )).program

      foo_class = mod.types["Foo"].metaclass
      bar_class = mod.types["Bar"].metaclass
      foo_int32_class = mod.generic_class("Foo", mod.int32).metaclass
      bar_int32_class = mod.generic_class("Bar", mod.int32).metaclass

      bar_int32_class.implements?(bar_class).should be_true
      bar_int32_class.implements?(foo_int32_class).should be_true
      bar_class.implements?(foo_class).should be_true
      foo_int32_class.implements?(foo_class).should be_true
      bar_int32_class.implements?(foo_class).should be_true
    end

    it "modules" do
      mod = semantic(%(
        module Foo; end
        module Bar; include Foo; end
        )).program

      foo_class = mod.types["Foo"].metaclass
      bar_class = mod.types["Bar"].metaclass
      bar_class.implements?(foo_class).should be_true
    end

    it "generic modules (1)" do
      mod = semantic(%(
        module Foo(T); end
        module Bar; include Foo(Int32); end
        )).program

      foo_class = mod.types["Foo"].metaclass
      foo_int32_class = mod.generic_module("Foo", mod.int32).metaclass
      bar_class = mod.types["Bar"].metaclass

      bar_class.implements?(foo_int32_class).should be_true
      bar_class.implements?(foo_class).should be_true
      foo_int32_class.implements?(foo_class).should be_true
    end

    it "generic modules (2)" do
      mod = semantic(%(
        module Foo; end
        module Bar(T); include Foo; end
        )).program

      foo_class = mod.types["Foo"].metaclass
      bar_class = mod.types["Bar"].metaclass
      bar_int32_class = mod.generic_module("Bar", mod.int32).metaclass

      bar_int32_class.implements?(bar_class).should be_true
      bar_int32_class.implements?(foo_class).should be_true
      bar_class.implements?(foo_class).should be_true
    end

    it "generic modules (3)" do
      mod = semantic(%(
        module Foo(T); end
        module Bar(T); include Foo(T); end
        )).program

      foo_class = mod.types["Foo"].metaclass
      bar_class = mod.types["Bar"].metaclass
      foo_int32_class = mod.generic_module("Foo", mod.int32).metaclass
      bar_int32_class = mod.generic_module("Bar", mod.int32).metaclass

      bar_int32_class.implements?(bar_class).should be_true
      bar_int32_class.implements?(foo_int32_class).should be_true
      bar_class.implements?(foo_class).should be_true
      foo_int32_class.implements?(foo_class).should be_true
      bar_int32_class.implements?(foo_class).should be_true
    end
  end
end
