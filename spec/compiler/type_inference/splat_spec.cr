require "../../spec_helper"

describe "Type inference: splat" do
  it "splats" do
    assert_type(%(
      def foo(*args)
        args
      end

      foo 1, 1.5, 'a'
      )) { tuple_of([int32, float64, char] of Type) }
  end

  it "errors on zero args with named arg and splat" do
    assert_error %(
      def foo(x, y = 1, *z)
      end

      foo
      ),
      "wrong number of arguments"
  end

  it "redefines method with splat (bug #248)" do
    assert_type(%(
      class Foo
        def bar(*x)
          1
        end
      end

      class Foo
        def bar(*x)
          'a'
        end
      end

      Foo.new.bar 1
      )) { char }
  end

  it "errors if splatting union" do
    assert_error %(
      a = {1} || {1, 2}
      foo *a
      ),
      "splatting a union (({Int32} | {Int32, Int32})) is not yet supported"
  end

  it "forwards tuple with an extra argument" do
    assert_type(%(
      def foo(*args)
        bar 1, *args
      end

      def bar(name, *args)
        args
      end

      x = foo 2
      x
      )) { tuple_of [int32] of TypeVar }
  end

  it "can splat after type filter left it as a tuple (#442)" do
    assert_type(%(
      def output(x, y)
        x + y
      end

      b = {1, 2} || nil
      if b
        output(*b)
      else
        4
      end
      )) { int32 }
  end

  it "errors if doesn't match splat with type restriction" do
    assert_error %(
      def foo(*args : Int32)
      end

      foo 1, 2, 3, 'a'
      ),
      "no overload matches"
  end

  it "works if matches splat with type restriction" do
    assert_type(%(
      def foo(*args : Int32)
        args[0]
      end

      foo 1, 2, 3
      )) { int32 }
  end

  it "oveloards with type restriction and splat (1)" do
    assert_type(%(
      def foo(arg : Int32)
        1
      end

      def foo(*args : Int32)
        'a'
      end

      foo 1
      )) { int32 }
  end

  it "oveloards with type restriction and splat (2)" do
    assert_type(%(
      def foo(arg : Int32)
        1
      end

      def foo(*args : Int32)
        'a'
      end

      foo 1, 2, 3
      )) { char }
  end

  it "errors if doesn't match splat with type restriction because of zero arguments" do
    assert_error %(
      def foo(*args : Int32)
      end

      foo
      ),
      "no overload matches"
  end

  it "oveloards with type restriction and splat (3)" do
    assert_type(%(
      def foo(*args : Char)
        "hello"
      end

      def foo(*args : Int32)
        1.5
      end

      foo 'a', 'b', 'c'
      )) { string }
  end

  it "oveloards with type restriction and splat (4)" do
    assert_type(%(
      def foo(*args : Char)
        "hello"
      end

      def foo(*args : Int32)
        1.5
      end

      foo 1, 2, 3
      )) { float64 }
  end

  it "oveloards with type restriction and splat (5)" do
    assert_type(%(
      def foo(*args : Int32)
        "hello"
      end

      def foo
        1.5
      end

      foo 1, 2, 3
      )) { string }
  end

  it "oveloards with type restriction and splat (6)" do
    assert_type(%(
      def foo(*args : Int32)
        "hello"
      end

      def foo
        1.5
      end

      foo
      )) { float64 }
  end

  it "oveloards with type restriction and splat (7)" do
    assert_type(%(
      def foo(*args)
        foo args
      end

      def foo(args : Tuple)
        'a'
      end

      foo 1, 2, 3
      )) { char }
  end
end
