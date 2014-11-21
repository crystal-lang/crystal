require "../../spec_helper"

describe "type inference: previous_def" do
  it "errors if there's no previous def" do
    assert_error %(
      def foo
        previous_def
      end

      foo
      ), "there is no previous definition of 'foo'"
  end

  it "types previous def" do
    assert_type(%(
      def foo
        1
      end

      def foo
        previous_def
      end

      foo
      )) { int32 }
  end

  it "types previous def in generic class" do
    assert_type(%(
      class Foo(T)
        def foo
          1
        end

        def foo
          previous_def
        end
      end

      Foo(Int32).new.foo
      )) { int32 }
  end

  it "types previous def with arguments" do
    assert_type(%(
      def foo(x)
        x
      end

      def foo(y)
        previous_def(1.5)
      end

      foo(1)
      )) { float64 }
  end

  it "types previous def with arguments but without parenthesis" do
    assert_type(%(
      def foo(x)
        x
      end

      def foo(y)
        previous_def
      end

      foo(1)
      )) { int32 }
  end

  it "types previous def with restrictions" do
    assert_type(%(
      def foo(x : Int32)
        x
      end

      def foo(y : Int32)
        previous_def
      end

      foo(1)
      )) { int32 }
  end

  it "types previous def when inside fun" do
    assert_type(%(
      def foo
        1
      end

      def foo
        x = ->{ previous_def }
        x.call
      end

      foo
      )) { int32 }
  end

  it "types previous def when inside fun and forwards args" do
    assert_type(%(
      def foo(z)
        z
      end

      def foo(z)
        x = ->{ previous_def }
        x.call
      end

      foo(1)
      )) { int32 }
  end
end
