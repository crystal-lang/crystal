require "../../spec_helper"

describe "Semantic: nilable cast" do
  it "types as?" do
    assert_type(%(
      1.as?(Float64)
      )) { nilable float64 }
  end

  it "types as? with union" do
    assert_type(%(
      (1 || 'a').as?(Int32)
      )) { nilable int32 }
  end

  it "types as? with nil" do
    assert_type(%(
      1.as?(Nil)
      )) { nil_type }
  end

  it "types as? with NoReturn" do
    assert_type(%(
      1.as?(NoReturn)
      )) { nil_type }
  end

  it "does upcast" do
    assert_type(%(
      class Foo
        def bar
          1
        end
      end

      class Bar < Foo
        def bar
          2
        end
      end

      Bar.new.as?(Foo)
      )) { nilable types["Foo"].virtual_type! }
  end

  it "doesn't crash with typeof no-type (#7441)" do
    assert_type(%(
      a = 1
      if a.is_a?(Char)
        1.as?(typeof(a))
      else
        ""
      end
      )) { string }
  end

  it "casts to module" do
    assert_type(%(
      module Moo
      end

      class Base
      end

      class Foo < Base
        include Moo
      end

      class Bar < Base
        include Moo
      end

      base = (Foo.new || Bar.new)
      base.as?(Moo)
      )) { union_of([types["Foo"], types["Bar"], nil_type] of Type) }
  end

  it "doesn't introduce type filter for nilable cast object (#12661)" do
    assert_type(%(
      val = 1 || false

      if val.as?(Char)
        true
      else
        val
      end
      )) { union_of(int32, bool) }
  end
end
