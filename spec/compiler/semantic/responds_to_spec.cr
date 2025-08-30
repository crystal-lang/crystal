require "../../spec_helper"

describe "Semantic: responds_to?" do
  it "is bool" do
    assert_type("1.responds_to?(:foo)") { bool }
  end

  it "restricts type inside if scope 1" do
    nodes = parse <<-CRYSTAL
      require "primitives"

      a = 1 || 'a'
      if a.responds_to?(:"+")
        a
      end
      CRYSTAL
    result = semantic nodes
    mod, nodes = result.program, result.node.as(Expressions)
    nodes.last.as(If).then.type.should eq(mod.int32)
  end

  it "restricts other types inside if else" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      a = 1 || 'a'
      if a.responds_to?(:"+")
        a.to_i32
      else
        a.ord
      end
      CRYSTAL
  end

  it "restricts in assignment" do
    assert_type(<<-CRYSTAL) { int32 }
      a = 1 || 'a'
      if (b = a).responds_to?(:abs)
        b
      else
        2
      end
      CRYSTAL
  end

  it "restricts virtual generic superclass to subtypes" do
    assert_type(<<-CRYSTAL) { nilable union_of(char, string) }
      module Foo(T)
      end

      class Bar
        include Foo(Int32)

        def foo
          'a'
        end
      end

      class Baz(T)
        include Foo(T)

        def foo
          ""
        end
      end

      x = Baz(Int32).new.as(Foo(Int32))
      if x.responds_to?(:foo)
        x.foo
      end
      CRYSTAL
  end

  it "restricts virtual generic module to including types (#8334)" do
    assert_type(<<-CRYSTAL) { nilable union_of(char, string) }
      class Foo(T)
      end

      class Bar < Foo(Int32)
        def foo
          'a'
        end
      end

      class Baz(T) < Foo(T)
        def foo
          ""
        end
      end

      x = Baz(Int32).new.as(Foo(Int32))
      if x.responds_to?(:foo)
        x.foo
      end
      CRYSTAL
  end
end
