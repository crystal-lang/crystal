require 'spec_helper'

describe 'Type inference: is_a?' do
  it "is bool" do
    assert_type("1.is_a?(Bool)") { bool }
  end

  it "restricts type inside if scope 1" do
    nodes = parse %q(
      a = 1 || 'a'
      if a.is_a?(Int)
        a
      end
      )
    mod, nodes = infer_type nodes
    nodes.last.then.type.should eq(mod.int32)
  end

  it "restricts type inside if scope 2" do
    nodes = parse %q(
      module Bar
      end

      class Foo(T)
        include Bar
      end

      a = Foo(Int32).new || 1
      if a.is_a?(Bar)
        a
      end
      )
    mod, nodes = infer_type nodes
    nodes.last.then.type.should eq(mod.types["Foo"].instantiate([mod.int32]))
  end

  it "restricts type inside if scope 3" do
    nodes = parse %q(
      class Foo
        def initialize(x)
          @x = x
        end
      end

      a = Foo.new(1) || 1
      if a.is_a?(Foo)
        a
      end
      )
    mod, nodes = infer_type nodes
    nodes.last.then.type.should eq(mod.types["Foo"])
  end

  it "restricts other types inside if else" do
    assert_type(%q(
      a = 1 || 'a'
      if a.is_a?(Int32)
        a.to_i32
      else
        a.ord
      end
      )) { int32 }
  end

  it "applies filter inside block" do
    assert_type(%q(
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
      )) { union_of(char, int32) }
  end
end
