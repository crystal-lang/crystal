require "../../spec_helper"

describe "Type inference: is_a?" do
  it "is bool" do
    assert_type("1.is_a?(Bool)") { bool }
  end

  it "restricts type inside if scope 1" do
    nodes = parse "
      a = 1 || 'a'
      if a.is_a?(Int)
        a
      end
      "
    result = infer_type nodes
    mod, nodes = result.program, result.node as Expressions
    (nodes.last as If).then.type.should eq(mod.int32)
  end

  it "restricts type inside if scope 2" do
    nodes = parse "
      module Bar
      end

      class Foo(T)
        include Bar
      end

      a = Foo(Int32).new || 1
      if a.is_a?(Bar)
        a
      end
      "

    result = infer_type nodes
    mod, nodes = result.program, result.node as Expressions

    foo = mod.types["Foo"] as GenericClassType
    (nodes.last as If).then.type.should eq(foo.instantiate([mod.int32] of TypeVar))
  end

  it "restricts type inside if scope 3" do
    nodes = parse "
      class Foo
        def initialize(x)
          @x = x
        end
      end

      a = Foo.new(1) || 1
      if a.is_a?(Foo)
        a
      end
      "

    result = infer_type nodes
    mod, nodes = result.program, result.node as Expressions
    (nodes.last as If).then.type.should eq(mod.types["Foo"])
  end

  it "restricts other types inside if else" do
    assert_type("
      a = 1 || 'a'
      if a.is_a?(Int32)
        a.to_i32
      else
        a.ord
      end
      ") { int32 }
  end

  it "applies filter inside block" do
    assert_type("
      lib C
        fun exit : NoReturn
      end

      def foo
        yield
      end

      foo do
        a = 1
        unless a.is_a?(Int32)
          C.exit
        end
      end

      x = 1

      foo do
        a = 'a' || 1
        x = a
      end

      x
      ") { union_of(char, int32) }
  end

  it "applies negative condition filter if then is no return" do
    assert_type("
      require \"prelude\"

      def foo
        if 1 == 1
          'a'
        else
          1
        end
      end

      def bar
        elems = foo
        if elems.is_a?(Char)
          raise \"No!\"
        end
        elems
      end

      bar
      ") { int32 }
  end

  it "checks simple type with union" do
    assert_type("
      a = 1
      if a.is_a?(Int32 | Char)
        a + 1
      else
        2
      end
      ") { int32 }
  end

  it "checks union with union" do
    assert_type("
      struct Char
        def +(other : Int32)
          self
        end
      end

      struct Bool
        def foo
          2
        end
      end

      a = 1 || 'a' || false
      if a.is_a?(Int32 | Char)
        a + 2
      else
        a.foo
      end
      ") { union_of(int32, char) }
  end

  it "restricts in assignment" do
    assert_type("
      a = 1 || 'a'
      if (b = a).is_a?(Int32)
        b
      else
        2
      end
      ") { int32 }
  end

  it "restricts type in else but lazily" do
    assert_type("
      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      foo = Foo.new(1)
      x = foo.x
      if x.is_a?(Int32)
        z = x + 1
      else
        z = x.foo_bar
      end

      z
      ") { int32 }
  end
end
