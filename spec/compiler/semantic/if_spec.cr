require "../../spec_helper"

describe "Semantic: if" do
  it "types an if without else" do
    assert_type("if 1 == 1; 1; end", inject_primitives: true) { nilable int32 }
  end

  it "types an if with else of same type" do
    assert_type("if 1 == 1; 1; else; 2; end", inject_primitives: true) { int32 }
  end

  it "types an if with else of different type" do
    assert_type("if 1 == 1; 1; else; 'a'; end", inject_primitives: true) { union_of(int32, char) }
  end

  it "types `if` with `&&` and assignment" do
    assert_type("
      struct Number
        def abs
          self
        end
      end

      class Foo
        def coco
          @a = 1 || nil
          if (b = @a) && 1 == 1
            b.abs
          end
        end
      end

      Foo.new.coco
      ", inject_primitives: true) { nilable int32 }
  end

  it "can invoke method on var that is declared on the right hand side of an and" do
    assert_type("
      if 1 == 2 && (b = 1)
        b + 1
      end
      ", inject_primitives: true) { nilable int32 }
  end

  it "errors if requires inside if" do
    assert_error %(
      if 1 == 2
        require "foo"
      end
      ),
      "can't require dynamically"
  end

  it "correctly filters type of variable if there's a raise with an interpolation that can't be typed" do
    assert_type(%(
      require "prelude"

      def bar
        bar
      end

      def foo
        a = 1 || nil
        unless a
          raise "Oh no \#{bar}"
        end
        a + 2
      end

      foo
      )) { int32 }
  end

  it "passes bug (related to #1729)" do
    assert_type(%(
      n = true ? 3 : 3.2
      if n.is_a?(Float64)
        n
      end
      n
      )) { union_of(int32, float64) }
  end

  it "restricts the type of the right hand side of an || when using is_a? (#1728)" do
    assert_type(%(
      n = 3 || "foobar"
      n.is_a?(String) || (n + 1 == 2)
      ), inject_primitives: true) { bool }
  end

  it "restricts type with !var and ||" do
    assert_type(%(
      a = 1 == 1 ? 1 : nil
      !a || a + 2
      ), inject_primitives: true) { union_of bool, int32 }
  end

  it "restricts type with !var.is_a?(...) and ||" do
    assert_type(%(
      a = 1 == 1 ? 1 : nil
      !a.is_a?(Int32) || a + 2
      ), inject_primitives: true) { union_of bool, int32 }
  end

  it "restricts type with !var.is_a?(...) and &&" do
    assert_type(%(
      a = 1 == 1 ? 1 : ""
      !a.is_a?(String) && a + 2
      ), inject_primitives: true) { union_of bool, int32 }
  end

  it "restricts with || (#2464)" do
    assert_type(%(
      struct Int32
        def foo
          1
        end
      end

      struct Char
        def foo
          1
        end
      end

      a = 1 || "" || 'a'
      if a.is_a?(Int32) || a.is_a?(Char)
        a.foo
      else
        1
      end
      )) { int32 }
  end

  it "doesn't restrict with || on different vars" do
    assert_error %(
      struct Int32
        def foo
          1
        end
      end

      struct Char
        def bar
          1
        end
      end

      a = 1 || "" || 'a'
      b = a
      if a.is_a?(Int32) || b.is_a?(Char)
        a.foo + b.bar
      end
      ),
      "undefined method"
  end

  it "doesn't restrict with || on var and non-restricting condition" do
    assert_error %(
      struct Int32
        def foo
          1
        end
      end

      a = 1 || "" || 'a'
      if a.is_a?(Int32) || 1 == 2
        a.foo
      end
      ),
      "undefined method"
  end

  it "restricts with || but doesn't unify types to base class" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
        def foo
          1
        end
      end

      class Baz < Foo
        def foo
          'a'
        end
      end

      a = Bar.new.as(Foo)
      if a.is_a?(Bar) || a.is_a?(Baz)
        a.foo
      else
        nil
      end
      )) { union_of(nil_type, int32, char) }
  end

  it "restricts with && always falsey" do
    assert_type(%(
      x = 1
      if (x.is_a?(String) && x.is_a?(String)) && x.is_a?(String)
        true
      else
        2
      end
      )) { union_of(bool, int32) }
  end

  it "doesn't filter and recombine when variables don't change in if" do
    assert_type(%(
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

      def foo(x : Foo)
        1
      end

      x = Bar.new.as(Moo)
      if x.is_a?(Bar) || x.is_a?(Baz)
      end
      foo(x)
      )) { int32 }
  end

  it "restricts and doesn't unify union types" do
    assert_type(%(
      class Foo
      end

      module M
        def m
          1
        end
      end

      class Bar < Foo
        include M
      end

      class Baz < Foo
        include M
      end

      a = Bar.new.as(Foo)
      if b = a.as?(M)
        b.m
      else
        nil
      end
      )) { union_of(nil_type, int32) }
  end

  it "types variable after unreachable else of && (#3360)" do
    assert_type(%(
      def test
        foo = 1 if 1
        return 1 unless foo && foo
        foo
      end

      test
      )) { int32 }
  end

  it "restricts || else (1) (#3266)" do
    assert_type(%(
      a = 1 || nil
      b = 1 || nil
      if !a || !b
        {1, 2}
      else
        {a, b}
      end
      )) { tuple_of([int32, int32]) }
  end

  it "restricts || else (2) (#3266)" do
    assert_type(%(
      a = 1 || nil
      if !a || 1
        'c'
      else
        a
      end
      )) { union_of char, int32 }
  end

  it "restricts || else (3) (#3266)" do
    assert_type(%(
      a = 1 || nil
      if 1 || !a
        'c'
      else
        a
      end
      )) { union_of char, int32 }
  end

  it "doesn't restrict || else in sub && (right)" do
    assert_type(%(
      def foo
        a = 1 || nil

        if false || (!a && false)
          return 1
        end

        a
      end

      foo
      )) { nilable int32 }
  end

  it "doesn't restrict || else in sub && (left)" do
    assert_type(%(
      def foo
        a = 1 || nil

        if (!a && false) || false
          return 1
        end

        a
      end

      foo
      )) { nilable int32 }
  end

  it "restricts || else in sub || (right)" do
    assert_type(%(
      def foo
        a = 1 || nil

        if false || (!a || false)
          return 1
        end

        a
      end

      foo
      )) { int32 }
  end

  it "restricts || else in sub || (left)" do
    assert_type(%(
      def foo
        a = 1 || nil

        if (!a || false) || false
          return 1
        end

        a
      end

      foo
      )) { int32 }
  end

  it "restricts && else in sub && (right)" do
    assert_type(%(
      def foo
        a = 1 || nil

        if !a && (!a && !a)
          return 1
        end

        a
      end

      foo
      )) { int32 }
  end

  it "restricts && else in sub && (left)" do
    assert_type(%(
      def foo
        a = 1 || nil

        if (!a && !a) && !a
          return 1
        end

        a
      end

      foo
      )) { int32 }
  end

  it "restricts || of more than 2 clauses (#8864)" do
    assert_type(%(
      def foo
        a = 1 || 2.0 || 'c' || ""

        if a.is_a?(Float64) || a.is_a?(Char) || a.is_a?(String)
          return 1
        end

        a
      end

      foo
      )) { int32 }
  end

  it "restricts && of !var.is_a(...)" do
    assert_type(%(
      def foo
        a = 1 || 2.0 || 'c'

        if !a.is_a?(Int32) && !a.is_a?(Float64)
          return true
        end

        a
      end

      foo
      )) { union_of int32, float64, bool }
  end

  it "doesn't consider nil type in else branch with if with && (#7434)" do
    assert_type(%(
      def foo
        if true && (y = 1 || nil)
        else
          return 1
        end
        y
      end

      foo
      )) { int32 }
  end

  it "includes pointer types in falsey branch" do
    assert_type(%(
      def foo
        x = 1
        y = false || pointerof(x) || nil

        if !y
          return y
        end
        1
      end

      foo
      )) { nilable union_of bool, pointer_of(int32), int32 }
  end

  it "doesn't fail on new variables inside typeof condition" do
    assert_type(%(
      def foo
        if typeof(x = 1)
          ""
        end
      end

      foo
      )) { nilable string }
  end

  it "doesn't fail on nested conditionals inside typeof condition" do
    assert_type(%(
      def foo
        if typeof(1 || 'a')
          ""
        end
      end

      foo
      )) { nilable string }
  end

  it "doesn't fail on Expressions condition (1)" do
    assert_type(%(
      def foo
        if (v = 1; true)
          typeof(v)
        end
      end

      foo
      )) { nilable int32.metaclass }
  end

  it "doesn't fail on Expressions condition (2)" do
    assert_type(%(
      def foo
        if (v = nil; true)
          typeof(v)
        end
      end

      foo
      )) { nilable nil_type.metaclass }
  end
end
