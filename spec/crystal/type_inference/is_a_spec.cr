#!/usr/bin/env bin/crystal -run
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
    mod, nodes = result.program, result.node
    assert_type nodes, Expressions

    if_node = nodes.last
    assert_type if_node, If

    if_node.then.type.should eq(mod.int32)
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
    mod, nodes = result.program, result.node

    foo = mod.types["Foo"]
    assert_type foo, GenericClassType

    assert_type nodes, Expressions

    if_node = nodes.last
    assert_type if_node, If

    if_node.then.type.should eq(foo.instantiate([mod.int32]))
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
    mod, nodes = result.program, result.node
    assert_type nodes, Expressions

    if_node = nodes.last
    assert_type if_node, If

    if_node.then.type.should eq(mod.types["Foo"])
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
end
