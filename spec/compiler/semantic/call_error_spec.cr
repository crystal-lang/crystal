require "../../spec_helper"

describe "Call errors" do
  it "says wrong number of arguments (to few arguments)" do
    assert_error %(
      def foo(x)
      end

      foo
      ),
      "wrong number of arguments for 'foo' (given 0, expected 1)"
  end

  it "says not expected to be invoked with a block" do
    assert_error %(
      def foo
      end

      foo {}
      ),
      "'foo' is not expected to be invoked with a block, but a block was given"
  end

  it "says expected to be invoked with a block" do
    assert_error %(
      def foo
        yield
      end

      foo
      ),
      "'foo' is expected to be invoked with a block, but no block was given"
  end

  it "says missing named argument" do
    assert_error %(
      def foo(*, x)
      end

      foo
      ),
      "missing argument: x"
  end

  it "says missing named arguments" do
    assert_error %(
      def foo(*, x, y)
      end

      foo
      ),
      "missing arguments: x, y"
  end

  it "says no parameter named" do
    assert_error %(
      def foo
      end

      foo(x: 1)
      ),
      "no parameter named 'x'"
  end

  it "says no parameters named" do
    assert_error %(
      def foo
      end

      foo(x: 1, y: 2)
      ),
      "no parameters named 'x', 'y'"
  end

  it "says argument already specified" do
    assert_error %(
      def foo(x)
      end

      foo(1, x: 2)
      ),
      "argument for parameter 'x' already specified"
  end

  it "says type mismatch for positional argument" do
    assert_error %(
      def foo(x : Int32, y : Int32)
      end

      foo(1, 'a')
      ),
      "expected second argument to 'foo' to be Int32, not Char"
  end

  it "says type mismatch for positional argument with two options" do
    assert_error %(
      def foo(x : Int32)
      end

      def foo(x : String)
      end

      foo('a')
      ),
      "expected first argument to 'foo' to be Int32 or String, not Char"
  end

  it "says type mismatch for positional argument with three options" do
    assert_error %(
      def foo(x : Int32)
      end

      def foo(x : String)
      end

      def foo(x : Bool)
      end

      foo('a')
      ),
      "expected first argument to 'foo' to be Bool, Int32 or String, not Char"
  end

  it "says type mismatch for named argument " do
    assert_error %(
      def foo(x : Int32, y : Int32)
      end

      foo(y: 1, x: 'a')
      ),
      "expected argument 'x' to 'foo' to be Int32, not Char"
  end
end
