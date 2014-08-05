#!/usr/bin/env bin/crystal --run
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
end
