require "../../spec_helper"

describe "Type inference: super" do
  it "types super without arguments" do
    assert_type("class Foo; def foo; 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo") { int32 }
  end

  it "types super without arguments and instance variable" do
    result = assert_type("class Foo; def foo; @x = 1; end; end; class Bar < Foo; def foo; super; end; end; bar = Bar.new; bar.foo; bar") do
      types["Bar"]
    end
    mod, type = result.program, result.node.type as NonGenericClassType

    superclass = type.superclass as NonGenericClassType
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
    mod, type = result.program, result.node.type as NonGenericClassType

    type.should eq(mod.types["Baz"])

    superclass = type.superclass as NonGenericClassType
    superclass2 = superclass.superclass as NonGenericClassType
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

  it "types super when inside fun" do
    assert_type(%(
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          x = ->{ super }
          x.call
        end
      end

      Bar.new.foo
      )) { int32 }
  end

  it "types super when inside fun and forwards args" do
    assert_type(%(
      class Foo
        def foo(z)
          z
        end
      end

      class Bar < Foo
        def foo(z)
          x = ->{ super }
          x.call
        end
      end

      Bar.new.foo(1)
      )) { int32 }
  end

  it "errors no superclass method in top-level" do
    assert_error %(
      super
      ), "there's no superclass in this scope"
  end

  it "errors no superclass method in top-level def" do
    assert_error %(
      def foo
        super
      end

      foo
      ), "there's no superclass in this scope"
  end

  it "errors no superclass method" do
    assert_error %(
      require "prelude"

      class Foo
        def foo(x)
          super
        end
      end

      Foo.new.foo(1)
      ), "undefined method 'foo'"
  end
end
