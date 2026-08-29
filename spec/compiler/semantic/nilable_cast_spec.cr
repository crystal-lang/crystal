require "../../spec_helper"

describe "Semantic: nilable cast" do
  it "types as?" do
    assert_type(<<-CRYSTAL) { nilable float64 }
      1.as?(Float64)
      CRYSTAL
  end

  it "types as? with union" do
    assert_type(<<-CRYSTAL) { nilable int32 }
      (1 || 'a').as?(Int32)
      CRYSTAL
  end

  it "types as? with nil" do
    assert_type(<<-CRYSTAL) { nil_type }
      1.as?(Nil)
      CRYSTAL
  end

  it "types as? with NoReturn" do
    assert_type(<<-CRYSTAL) { nil_type }
      1.as?(NoReturn)
      CRYSTAL
  end

  it "does upcast" do
    assert_type(<<-CRYSTAL) { nilable types["Foo"].virtual_type! }
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
      CRYSTAL
  end

  it "doesn't crash with typeof no-type (#7441)" do
    assert_type(<<-CRYSTAL) { string }
      a = 1
      if a.is_a?(Char)
        1.as?(typeof(a))
      else
        ""
      end
      CRYSTAL
  end

  it "casts to module" do
    assert_type(<<-CRYSTAL) { union_of([types["Foo"], types["Bar"], nil_type] of Type) }
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
      CRYSTAL
  end

  it "doesn't introduce type filter for nilable cast object (#12661)" do
    assert_type(<<-CRYSTAL) { union_of(int32, bool) }
      val = 1 || false

      if val.as?(Char)
        true
      else
        val
      end
      CRYSTAL
  end
end
