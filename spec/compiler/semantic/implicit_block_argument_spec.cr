require "../../spec_helper"

describe "Semantic: implicit block argument" do
  it "errors if implicit block argument outside of block" do
    assert_error %(
      _1
      ),
      "implcit block argument can only be used inside a block"
  end

  it "uses implicit block argument" do
    assert_type(%(
      def foo
        yield 1, 'a', true
      end

      foo do
        {_1, _2, _3}
      end
    )) { tuple_of [int32, char, bool] }
  end

  it "errors if uses implicit argument where positional argument already exists" do
    assert_error %(
        def foo
          yield 1
        end

        foo do |x|
          _1
        end
      ),
      "an explicit block argument at position 1 already exists"
  end

  it "uses implicit block argument with macro" do
    assert_type(%(
      macro moo(x)
        {{x}}
      end

      def foo
        yield 1
      end

      def bar
        foo do
          moo(_1)
        end
      end

      bar
    )) { int32 }
  end

  it "uses implicit block argument with macro (top level)" do
    assert_type(%(
      macro moo(x)
        {{x}}
      end

      def foo
        yield 1
      end

      foo do
        moo(_1)
      end
    )) { int32 }
  end
end
