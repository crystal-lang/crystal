#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: struct" do
  it "types struct declaration" do
    assert_type("
      struct Foo
      end
      Foo
      ") do
      str = types["Foo"] as NonGenericClassType
      str.struct?.should be_true
      str.metaclass
    end
  end

  it "types generic struct declaration" do
    assert_type("
      struct Foo(T)
      end
      Foo(Int32)
      ") do
      str = types["Foo"] as GenericClassType
      str.struct?.should be_true

      str_inst = str.instantiate([int32] of TypeVar )
      str_inst.struct?.should be_true
      str_inst.metaclass
    end
  end

  it "doesn't allow struct to participate in virtual" do
    assert_type("
      struct Foo
      end

      struct Bar < Foo
      end

      Foo.new || Bar.new
      ") do
        union_of(types["Foo"], types["Bar"])
      end
  end

  it "can't be nilable" do
    assert_type("
      struct Foo
      end

      Foo.new || nil
      ") do | mod|
        type = union_of(types["Foo"], mod.nil)
        type.should_not be_a(NilableType)
        type
      end
  end

  it "can't extend struct from class" do
    assert_error "
      struct Foo < Reference
      end
      ", "can't make struct 'Foo' inherit class 'Reference'"
  end

  it "can't extend class from struct" do
    assert_error "
      struct Foo
      end

      class Bar < Foo
      end
      ", "can't make class 'Bar' inherit struct 'Foo'"
  end

  it "can't reopen as different type" do
    assert_error "
      struct Foo
      end

      class Foo
      end
      ", "Foo is not a class, it's a struct"
  end
end
