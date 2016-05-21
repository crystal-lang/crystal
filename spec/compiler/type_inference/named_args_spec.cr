require "../../spec_helper"

describe "Type inference: named args" do
  it "errors if named arg not found" do
    assert_error %(
      def foo(x, y = 1, z = 2)
      end

      foo 1, w: 3
      ),
      "no argument named 'w'"
  end

  it "errors if named arg already specified" do
    assert_error %(
      def foo(x, y = 1, z = 2)
      end

      foo 1, x: 1
      ),
      "argument 'x' already specified"
  end

  it "errors if named arg not found in new" do
    assert_error %(
      class Foo
        def initialize(x, y = 1, z = 2)
        end
      end

      Foo.new 1, w: 3
      ),
      "no argument named 'w'"
  end

  it "errors if named arg already specified" do
    assert_error %(
      class Foo
        def initialize(x, y = 1, z = 2)
        end
      end

      Foo.new 1, x: 1
      ),
      "argument 'x' already specified"
  end

  it "errors if doesn't pass named arg restriction" do
    assert_error %(
      def foo(x : Int32 = 1)
      end

      foo x: 1.5
      ),
      "no overload matches"
  end

  it "errors if named arg already specified but in same position" do
    assert_error %(
      def foo(headers = nil)
      end

      foo 1, headers: 2
      ),
      "argument 'headers' already specified"
  end

  it "sends one regular argument as named argument" do
    assert_type(%(
      def foo(x)
        x
      end

      foo x: 1
      )) { int32 }
  end

  it "sends two regular arguments as named arguments" do
    assert_type(%(
      def foo(x, y)
        x + y
      end

      foo x: 1, y: 2
      )) { int32 }
  end

  it "sends two regular arguments as named arguments in inverted position (1)" do
    assert_type(%(
      def foo(x, y)
        x
      end

      foo y: 1, x: "foo"
      )) { string }
  end

  it "sends two regular arguments as named arguments in inverted position (2)" do
    assert_type(%(
      def foo(x, y)
        y
      end

      foo y: 1, x: "foo"
      )) { int32 }
  end

  it "errors if named arg matches single splat argument" do
    assert_error %(
      def foo(*y)
      end

      foo x: 1, y: 2
      ),
      "no argument named 'x'"
  end

  it "errors if named arg matches splat argument" do
    assert_error %(
      def foo(x, *y)
      end

      foo x: 1, y: 2
      ),
      "wrong number of arguments for 'foo' (given 0, expected 1+)"
  end

  it "allows named arg if there's a splat" do
    assert_type(%(
      def foo(*y, x)
        { x, y }
      end

      foo 1, x: 'a'
      )) { tuple_of([char, tuple_of([int32])]) }
  end

  it "errors if missing one argument" do
    assert_error %(
      def foo(x, y, z)
      end

      foo x: 1, y: 2
      ),
      "missing argument: z"
  end

  it "errors if missing two arguments" do
    assert_error %(
      def foo(x, y, z)
      end

      foo y: 2
      ),
      "missing arguments: x, z"
  end

  it "doesn't include arguments with default values in missing arguments error" do
    assert_error %(

      def foo(x, z, y = 1)
      end

      foo(x: 1)
      ),
      "missing argument: z"
  end

  it "says no overload matches with named arg" do
    assert_error %(
      def foo(x, y)
      end

      def foo(x, y, z)
      end

      foo(x: 2)
      ),
      "wrong number of arguments for 'foo' (given 0, expected 2..3)"
  end

  it "gives correct error message for missing args after *" do
    assert_error %(
      def foo(*, x, y)
      end

      foo
      ),
      "missing arguments: x, y"
  end

  it "overloads based on required named args" do
    assert_type(%(
      def foo(x, *, y)
        1
      end

      def foo(x, *, z)
        'a'
      end

      a = foo(1, y: 2)
      b = foo(1, z: 2)

      {a, b}
      )) { tuple_of([int32, char]) }
  end

  it "overloads based on required named args, with restrictions" do
    assert_type(%(
      def foo(x, *, z : Int32)
        1
      end

      def foo(x, *, z : Float64)
        'a'
      end

      a = foo(1, z: 1)
      b = foo(1, z: 1.5)

      {a, b}
      )) { tuple_of([int32, char]) }
  end

  it "uses bare splat in new" do
    assert_type(%(
      class Foo
        def initialize(*, y = nil)
        end
      end

      Foo.new
      )) { types["Foo"] }
  end
end
