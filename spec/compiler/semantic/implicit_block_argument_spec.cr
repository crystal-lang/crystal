require "../../spec_helper"

describe "Semantic: implicit block argument" do
  it "errors if implicit block argument outside of block" do
    assert_error %(
      &1
      ),
      "implcit block argument can only be used inside a block"
  end

  it "uses implicit block argument with call" do
    assert_type(%(
      def foo
        yield 1
      end

      def bar(x)
        x
      end

      foo &bar(&1)
    )) { int32 }
  end

  it "uses implicit block argument with parentheses" do
    assert_type(%(
      def foo
        yield 1
      end

      foo &(&1 &+ 1)
    )) { int32 }
  end

  it "uses implicit block argument with tuple syntax" do
    assert_type(%(
      def foo
        yield 1, 'a', true
      end

      foo &{&1, &2, &3}
    )) { tuple_of [int32, char, bool] }
  end
end
