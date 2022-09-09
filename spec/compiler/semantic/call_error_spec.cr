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
end
