require "../../spec_helper"

describe "Semantic: previous_def" do
  it "errors if there's no previous def" do
    assert_error %(
      def foo
        previous_def
      end

      foo
      ), "there is no previous definition of 'foo'"
  end

  it "types previous def" do
    assert_type(<<-CRYSTAL) { int32 }
      def foo
        1
      end

      def foo
        previous_def
      end

      foo
      CRYSTAL
  end

  it "types previous def in generic class" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo(T)
        def foo
          1
        end

        def foo
          previous_def
        end
      end

      Foo(Int32).new.foo
      CRYSTAL
  end

  it "types previous def with explicit arguments" do
    assert_type(<<-CRYSTAL) { float64 }
      def foo(x)
        x
      end

      def foo(y)
        previous_def(1.5)
      end

      foo(1)
      CRYSTAL
  end

  it "types previous def with forwarded arguments, def has parameters" do
    assert_type(<<-CRYSTAL) { int32 }
      def foo(x)
        x
      end

      def foo(y)
        previous_def
      end

      foo(1)
      CRYSTAL
  end

  it "types previous def with forwarded arguments, def has bare splat parameter (#8895)" do
    assert_type(<<-CRYSTAL) { int32 }
      def foo(*, x)
        x
      end

      def foo(*, x)
        previous_def
      end

      foo(x: 1)
      CRYSTAL
  end

  it "types previous def with named arguments, def has bare splat parameter (#8895)" do
    assert_type(<<-CRYSTAL) { union_of int32, char }
      def foo(*, x)
        x
      end

      def foo(*, x)
        previous_def x: x || 'a'
      end

      foo(x: 1)
      CRYSTAL
  end

  it "types previous def with named arguments, def has bare splat parameter (2) (#8895)" do
    assert_type(<<-CRYSTAL) { union_of int32, char }
      def foo(x)
        x
      end

      def foo(x)
        previous_def x: x || 'a'
      end

      foo(1)
      CRYSTAL
  end

  it "types previous def with forwarded arguments, different internal names (#8895)" do
    assert_type(<<-CRYSTAL) { int32 }
      def foo(*, x a)
        a
      end

      def foo(*, x b)
        previous_def
      end

      foo(x: 1)
      CRYSTAL
  end

  it "types previous def with named arguments, def has double splat parameter (#8895)" do
    assert_type(<<-CRYSTAL) { named_tuple_of({"x": int32, "y": char}) }
      def foo(**opts)
        opts
      end

      def foo(**opts)
        previous_def
      end

      foo(x: 1, y: 'a')
      CRYSTAL
  end

  it "types previous def with restrictions" do
    assert_type(<<-CRYSTAL) { int32 }
      def foo(x : Int32)
        x
      end

      def foo(y : Int32)
        previous_def
      end

      foo(1)
      CRYSTAL
  end

  it "types previous def when inside fun" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo
        1
      end

      def foo
        x = ->{ previous_def }
        x.call
      end

      foo
      CRYSTAL
  end

  it "types previous def when inside fun and forwards args" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo(z)
        z
      end

      def foo(z)
        x = ->{ previous_def }
        x.call
      end

      foo(1)
      CRYSTAL
  end

  it "says wrong number of arguments for previous_def (#1223)" do
    assert_error %(
      class Foo
        def x
        end

        def x
          previous_def(1)
        end
      end

      Foo.new.x
      ),
      "wrong number of arguments"
  end
end
