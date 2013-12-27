#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: cast" do
  it "casts to same type is ok" do
    assert_type("1 as Int32 ") { int32 }
  end

  it "casts to incompatible type gives error" do
    assert_error "1 as Float64",
      "can't cast Int32 to Float64"
  end

  pending "casts from union to incompatible union gives error" do
    assert_error "(1 || 1.5) as Int32 | Char",
      "can't cast Int32 | Float64 to Int32 | Char"
  end

  it "casts from union to compatible union" do
    assert_type("(1 || 1.5 || 'a') as Int32 | Float64") { union_of(int32, float64) }
  end

  it "casts to compatible type and use it" do
    assert_type("
      class Foo
      end

      class Bar < Foo
        def coco
          1
        end
      end

      a = Foo.new || Bar.new
      b = a as Bar
      b.coco
    ") { int32 }
  end

  it "casts pointer of one type to another type" do
    assert_type("
      a = 1
      p = pointerof(a)
      p as Float64*
    ") { pointer_of(float64) }
  end

  it "casts pointer to another type" do
    assert_type("
      a = 1
      p = pointerof(a)
      p as String
    ") { types["String"] }
  end

  it "casts to module" do
    assert_type("
      module Moo
      end

      class Foo
      end

      class Bar < Foo
        include Moo
      end

      class Baz < Foo
        include Moo
      end

      f = Foo.new || Bar.new || Baz.new
      f as Moo
      ") { union_of(types["Bar"].hierarchy_type, types["Baz"].hierarchy_type) }
  end
end
