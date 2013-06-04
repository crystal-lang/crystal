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
    nodes.last.then.type.should eq(mod.int)
  end

  it "restricts type inside if scope 2" do
    nodes = parse %q(
      module Bar
      end

      class Foo(T)
        include Bar
      end

      a = Foo(Int).new
      if a.is_a?(Bar)
        a
      end
      )
    mod, nodes = infer_type nodes
    nodes.last.then.type.should eq(nodes[2].type)
  end

  it "restricts type inside if scope 3" do
    nodes = parse %q(
      class Foo
        def initialize(x)
          @x = x
        end
      end

      a = Foo.new(1)
      if a.is_a?(Foo)
        a
      end
      )
    mod, nodes = infer_type nodes
    nodes.last.then.type.should eq(nodes[1].type)
  end
end
