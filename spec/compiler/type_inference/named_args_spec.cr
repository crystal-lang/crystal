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

  it "errors if named arg matches splat argument" do
    assert_error %(
      def foo(x, *y)
      end

      foo x: 1, y: 2
      ),
      "can't use named args with methods that have a splat argument"
  end

  it "doesn't allow named arg if there's a splat" do
    assert_error %(
      def foo(*y, x)
      end

      foo 1, x: 2
      ),
      "can't use named args with methods that have a splat argument"
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

  it "says no overload matches with named arg" do
    assert_error %(
      def foo(x, y)
      end

      def foo(x, y, z)
      end

      foo(x: 2)
      ),
      "no overload matches"
  end
end
