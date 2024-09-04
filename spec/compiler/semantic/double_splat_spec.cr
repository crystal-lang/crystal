require "../../spec_helper"

describe "Semantic: double splat" do
  it "double splats named argument into arguments (1)" do
    assert_type(%(
      def foo(x, y)
        x
      end

      tup = {x: 1, y: 'a'}
      foo **tup
      )) { int32 }
  end

  it "double splats named argument into arguments (2)" do
    assert_type(%(
      def foo(x, y)
        x
      end

      tup = {y: 'a', x: 1}
      foo **tup
      )) { int32 }
  end

  it "errors if duplicate keys on call side with two double splats" do
    assert_error %(
      def foo(**args)
      end

      t1 = {x: 1, y: 2}
      t2 = {z: 3, x: 4}
      foo **t1, **t2
      ),
      "duplicate key: x"
  end

  it "errors if duplicate keys on call side with double splat and named args" do
    assert_error %(
      def foo(**args)
      end

      t1 = {x: 1, y: 2}
      foo **t1, z: 3, x: 4
      ),
      "duplicate key: x"
  end

  it "errors missing argument with double splat" do
    assert_error %(
      def foo(x, y)
      end

      tup = {x: 1}
      foo **tup
      ),
      "missing argument: y"
  end

  it "matches double splat on method (empty)" do
    assert_type(%(
      def foo(**args)
        args
      end

      foo
      )) { named_tuple_of({} of String => Type) }
  end

  it "matches double splat on method with named args" do
    assert_type(%(
      def foo(**args)
        args
      end

      foo x: 1, y: 'a'
      )) { named_tuple_of({"x": int32, "y": char}) }
  end

  it "matches double splat on method with named args and regular args" do
    assert_type(%(
      def foo(x, **args)
        args
      end

      foo y: 'a', z: 3, x: "foo"
      )) { named_tuple_of({"y": char, "z": int32}) }
  end

  it "matches double splat with regular splat" do
    assert_type(%(
      def foo(*args, **options)
        {args, options}
      end

      foo 1, 'a', x: "foo", y: true
      )) { tuple_of([tuple_of([int32, char]), named_tuple_of({"x": string, "y": bool})]) }
  end

  it "uses double splat in new" do
    assert_type(%(
      class Foo
        @x : Int32

        def initialize(**options)
          @x = options[:x]
        end

        def x
          @x
        end
      end

      Foo.new(x: 1).x
      )) { int32 }
  end

  it "uses restriction on double splat, doesn't match with empty named tuple" do
    assert_error %(
      def foo(**options : Int32)
      end

      foo
      ),
      "no overload matches"
  end

  it "uses restriction on double splat, doesn't match with empty named tuple (2)" do
    assert_error %(
      def foo(x, **options : Int32)
      end

      foo x: 1
      ),
      "no overload matches"
  end

  it "uses restriction on double splat, means all types must be that type" do
    assert_error %(
      def foo(**options : Int32)
      end

      foo x: 1, y: 'a'
      ),
      "no overload matches"
  end

  it "overloads based on double splat restriction" do
    assert_type(%(
      def foo(**options : Int32)
        true
      end

      def foo(**options : Char)
        "foo"
      end

      x1 = foo x: 'a', y: 'b'
      x2 = foo x: 1, y: 2
      {x1, x2}
      )) { tuple_of([string, bool]) }
  end

  it "uses double splat restriction" do
    assert_type(%(
      def foo(**options : **T) forall T
        T
      end

      foo x: 1, y: 'a'
      )) { named_tuple_of({"x" => int32, "y" => char}).metaclass }
  end

  it "uses double splat restriction, matches empty" do
    assert_type(%(
      def foo(**options : **T) forall T
        T
      end

      foo
      )) { named_tuple_of({} of String => Type).metaclass }
  end

  it "uses double splat restriction with concrete type" do
    assert_error %(
      struct NamedTuple(T)
        def self.foo(**options : **T)
        end
      end

      NamedTuple(x: Int32, y: Char).foo(x: 1, y: true)
      ),
      "no overload matches"
  end

  it "matches named args producing an empty double splat (#2678)" do
    assert_type(%(
      def test(x, **kwargs)
        kwargs
      end

      test(x: 7)
      )) { named_tuple_of({} of String => Type) }
  end
end
