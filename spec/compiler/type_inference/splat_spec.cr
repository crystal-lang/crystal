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
end
