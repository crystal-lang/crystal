require "../../spec_helper"

describe "Semantic: super" do
  it "types super without arguments" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          super
        end
      end

      Bar.new.foo
      CRYSTAL
  end

  it "types super without arguments and instance variable" do
    result = assert_type(<<-CRYSTAL) { types["Bar"] }
      class Foo
        def foo
          @x = 1
        end
      end

      class Bar < Foo
        def foo
          super
        end
      end

      bar = Bar.new
      bar.foo
      bar
      CRYSTAL

    mod, type = result.program, result.node.type.as(NonGenericClassType)

    superclass = type.superclass.as(NonGenericClassType)
    superclass.instance_vars["@x"].type.should eq(mod.nilable(mod.int32))
  end

  it "types super with forwarded arguments, parent has parameters" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def foo(x)
          x
        end
      end

      class Bar < Foo
        def foo(x)
          super
        end
      end

      Bar.new.foo(1)
      CRYSTAL
  end

  it "types super with forwarded arguments, def has bare splat parameter (#8895)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def foo(*, x)
          x
        end
      end

      class Bar < Foo
        def foo(*, x)
          super
        end
      end

      Bar.new.foo(x: 1)
      CRYSTAL
  end

  it "types super with named arguments, def has bare splat parameter (#8895)" do
    assert_type(<<-CRYSTAL) { union_of int32, char }
      class Foo
        def foo(*, x)
          x
        end
      end

      class Bar < Foo
        def foo(*, x)
          super x: x || 'a'
        end
      end

      Bar.new.foo(x: 1)
      CRYSTAL
  end

  it "types super with named arguments, def has bare splat parameter (2) (#8895)" do
    assert_type(<<-CRYSTAL) { union_of int32, char }
      class Foo
        def foo(x)
          x
        end
      end

      class Bar < Foo
        def foo(x)
          super x: x || 'a'
        end
      end

      Bar.new.foo(1)
      CRYSTAL
  end

  it "types super with forwarded arguments, different internal names (#8895)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def foo(*, x a)
          a
        end
      end

      class Bar < Foo
        def foo(*, x b)
          super
        end
      end

      Bar.new.foo(x: 1)
      CRYSTAL
  end

  it "types super with forwarded arguments, def has double splat parameter (#8895)" do
    assert_type(<<-CRYSTAL) { named_tuple_of({"x": int32, "y": char}) }
      class Foo
        def foo(**opts)
          opts
        end
      end

      class Bar < Foo
        def foo(**opts)
          super
        end
      end

      Bar.new.foo(x: 1, y: 'a')
      CRYSTAL
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
    result = semantic nodes
    mod, type = result.program, result.node.type.as(NonGenericClassType)

    type.should eq(mod.types["Baz"])

    superclass = type.superclass.as(NonGenericClassType)
    superclass2 = superclass.superclass.as(NonGenericClassType)
    superclass2.instance_vars["@x"].type.should eq(mod.int32)
  end

  it "types super when container method is defined in parent class two levels up" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "types super when inside fun" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
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
      CRYSTAL
  end

  it "types super when inside fun and forwards args" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
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
      CRYSTAL
  end

  it "errors no superclass method in top-level" do
    assert_error <<-CRYSTAL, "there's no superclass in this scope"
      super
      CRYSTAL
  end

  it "errors no superclass method in top-level def" do
    assert_error <<-CRYSTAL, "there's no superclass in this scope"
      def foo
        super
      end

      foo
      CRYSTAL
  end

  it "errors no superclass method" do
    assert_error <<-CRYSTAL, "undefined method 'foo'"
      require "prelude"

      class Foo
        def foo(x)
          super
        end
      end

      Foo.new.foo(1)
      CRYSTAL
  end

  it "finds super initialize if not explicitly defined in superclass, 1 (#273)" do
    assert_type(<<-CRYSTAL) { types["Foo"] }
      class Foo
        def initialize
          super
        end
      end

      Foo.new
      CRYSTAL
  end

  it "finds super initialize if not explicitly defined in superclass, 2 (#273)" do
    assert_type(<<-CRYSTAL) { types["Foo"] }
      class Base
      end

      class Foo < Base
        def initialize
          super
        end
      end

      Foo.new
      CRYSTAL
  end

  it "says correct error message when no overload matches in super call (#272)" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'Foo#initialize' to be Char, not Int32"
      abstract class Foo
        def initialize(x : Char)
        end
      end

      class Bar < Foo
        def initialize(a, b)
          super(a)
        end
      end

      Bar.new(1, 2)
      CRYSTAL
  end

  it "calls super in module method (1) (#556)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Parent
        def a
          1
        end
      end

      module Mod
        def a
          super
        end
      end

      class Child < Parent
        include Mod
      end

      Child.new.a
      CRYSTAL
  end

  it "calls super in module method (2) (#556)" do
    assert_type(<<-CRYSTAL) { char }
      class Parent
        def a
          1
        end
      end

      module Mod2
        def a
          'a'
        end
      end

      module Mod
        def a
          super
        end
      end

      class Child < Parent
        include Mod2
        include Mod
      end

      Child.new.a
      CRYSTAL
  end

  it "calls super in module method (3) (#556)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Parent
        def a
          1
        end
      end

      module Mod2
      end

      module Mod
        def a
          super
        end
      end

      class Child < Parent
        include Mod2
        include Mod
      end

      Child.new.a
      CRYSTAL
  end

  it "errors if calling super on module method and not found" do
    assert_error <<-CRYSTAL, "undefined method 'a'"
      module Mod
        def a
          super
        end
      end

      class Child
        include Mod
      end

      Child.new.a
      CRYSTAL
  end

  it "calls super in generic module method" do
    assert_type(<<-CRYSTAL) { int32 }
      class Parent
        def a
          1
        end
      end

      module Mod(T)
        def a
          super
        end
      end

      class Child < Parent
        include Mod(Int32)
      end

      Child.new.a
      CRYSTAL
  end

  it "doesn't error if invoking super and match isn't found in direct superclass (even though it's find in one superclass)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo(x)
          'a'
        end
      end

      class Baz < Bar
        def foo
          super()
        end
      end

      Baz.new.foo
      CRYSTAL
  end

  it "errors if invoking super and match isn't found in direct superclass in initialize (even though it's find in one superclass)" do
    assert_error <<-CRYSTAL, "wrong number of argument"
      class Foo
        def initialize
        end
      end

      class Bar < Foo
        def initialize(x)
        end
      end

      class Baz < Bar
        def initialize
          super()
        end
      end

      Baz.new
      CRYSTAL
  end

  it "gives correct error when calling super and target is abstract method (#2675)" do
    assert_error <<-CRYSTAL, "undefined method 'Base#method()'"
      abstract class Base
        abstract def method
      end

      class Sub < Base
        def method
          super
        end
      end

      Sub.new.method
      CRYSTAL
  end

  it "errors on super outside method (#4481)" do
    assert_error <<-CRYSTAL, "can't use 'super' outside method"
      class Foo
        super
      end
      CRYSTAL
  end

  it "errors on super where only target would be a top level method (#5201)" do
    assert_error <<-CRYSTAL, "no overload matches 'bar'"
      def bar
      end

      class Foo
        def bar
          super
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "invokes super inside macro (#6636)" do
    assert_type(<<-CRYSTAL) { char }
      class Foo
        def foo
          1
        end

        def foo(x)
          'a'
        end
      end

      class Bar < Foo
        def foo(x)
          {% begin %}
            super
          {% end %}
        end
      end

      Bar.new.foo(3)
      CRYSTAL
  end
end
