require "../../spec_helper"

describe "Semantic: is_a?" do
  it "is bool" do
    assert_type("1.is_a?(Bool)") { bool }
  end

  it "restricts type inside if scope 1" do
    nodes = parse <<-CRYSTAL
      a = 1 || 'a'
      if a.is_a?(Int)
        a
      end
      CRYSTAL
    result = semantic nodes
    mod, nodes = result.program, result.node.as(Expressions)
    nodes.last.as(If).then.type.should eq(mod.int32)
  end

  it "restricts type inside if scope 2" do
    nodes = parse <<-CRYSTAL
      module Bar
      end

      class Foo(T)
        include Bar
      end

      a = Foo(Int32).new || 1
      if a.is_a?(Bar)
        a
      end
      CRYSTAL

    result = semantic nodes
    mod, nodes = result.program, result.node.as(Expressions)

    foo = mod.types["Foo"].as(GenericClassType)
    nodes.last.as(If).then.type.should eq(foo.instantiate([mod.int32] of TypeVar))
  end

  it "restricts type inside if scope 3" do
    nodes = parse <<-CRYSTAL
      class Foo
        def initialize(@x : Int32)
        end
      end

      a = Foo.new(1) || 1
      if a.is_a?(Foo)
        a
      end
      CRYSTAL

    result = semantic nodes
    mod, nodes = result.program, result.node.as(Expressions)
    nodes.last.as(If).then.type.should eq(mod.types["Foo"])
  end

  it "restricts other types inside if else" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      a = 1 || 'a'
      if a.is_a?(Int32)
        a.to_i32
      else
        a.ord
      end
      CRYSTAL
  end

  it "applies filter inside block" do
    assert_type(<<-CRYSTAL) { union_of(char, int32) }
      lib LibC
        fun exit : NoReturn
      end

      def foo
        yield
      end

      foo do
        a = 1
        unless a.is_a?(Int32)
          LibC.exit
        end
      end

      x = 1

      foo do
        a = 'a' || 1
        x = a
      end

      x
      CRYSTAL
  end

  it "applies negative condition filter if then is no return" do
    assert_type(<<-CRYSTAL) { int32 }
      require "prelude"

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
          raise "No!"
        end
        elems
      end

      bar
      CRYSTAL
  end

  it "checks simple type with union" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      a = 1
      if a.is_a?(Int32 | Char)
        a + 1
      else
        2
      end
      CRYSTAL
  end

  it "checks union with union" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { union_of(int32, char) }
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
      CRYSTAL
  end

  it "restricts in assignment" do
    assert_type(<<-CRYSTAL) { int32 }
      a = 1 || 'a'
      if (b = a).is_a?(Int32)
        b
      else
        2
      end
      CRYSTAL
  end

  it "restricts type in else but lazily" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      class Foo
        def initialize(@x : Int32)
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
      CRYSTAL
  end

  it "types if is_a? preceded by return if (preserves nops)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nil_type }
      def coco
        return if 1 == 1

        if 1.is_a?(Int32)
        end
      end

      coco
      CRYSTAL
  end

  it "restricts type inside if else when used with module type" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { bool }
      module Moo
      end

      struct Int32
        def foo
          true
        end
      end

      class Foo
        include Moo
      end

      a = 1 == 1 ? 1 : Foo.new.as(Moo)
      unless a.is_a?(Moo)
        a.foo
      else
        false
      end
      CRYSTAL
  end

  it "doesn't fail on untyped is_a (#10317)" do
    assert_no_errors(<<-CRYSTAL)
      require "prelude"

      def foo(&block)
      end

      class Sup
      end

      foo do
        Sup.new.is_a?(Sup)
      end
      CRYSTAL
  end

  it "does is_a? from virtual metaclass to generic metaclass (#12302)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { nilable generic_class("B", string).metaclass }
      class A
      end

      class B(T) < A
      end

      x = B(String).new.as(A).class

      if x.is_a?(B(String).class)
        x
      else
        nil
      end
      CRYSTAL
  end
end
