#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: super" do
  it "types super without arguments" do
    assert_type("class Foo; def foo; 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo") { int32 }
  end

  it "types super without arguments and instance variable" do
    result = assert_type("class Foo; def foo; @x = 1; end; end; class Bar < Foo; def foo; super; end; end; bar = Bar.new; bar.foo; bar") do
      types["Bar"]
    end
    mod, type = result.program, result.node.type
    assert_type type, NonGenericClassType

    superclass = type.superclass
    assert_type superclass, NonGenericClassType

    superclass.instance_vars["@x"].type.should eq(mod.union_of(mod.nil, mod.int32))
  end

  it "types super without arguments but parent has arguments" do
    assert_type("class Foo; def foo(x); x; end; end; class Bar < Foo; def foo(x); super; end; end; Bar.new.foo(1)") { int32 }
  end

  it "types super when container method is defined in parent class" do
    nodes = parse "
      class Foo
        def initialize
          @x = 1
        end
      end
      class Bar < Foo
        def initialize
          super
        end
      end
      class Baz < Bar
      end
      Baz.new
      "
    result = infer_type nodes
    mod, type = result.program, result.node.type

    type.should eq(mod.types["Baz"])

    assert_type type, NonGenericClassType
    superclass = type.superclass

    assert_type superclass, NonGenericClassType
    superclass2 = superclass.superclass
    assert_type superclass2, NonGenericClassType

    superclass2.instance_vars["@x"].type.should eq(mod.int32)
  end

  it "types super when container method is defined in parent class two levels up" do
    assert_type("
      class Base
        def foo
          1
        end
      end

      class Foo < Base
      end

      class Bar < Foo
        def foo
          super
        end
      end

      Bar.new.foo
      ") { int32 }
  end
end
