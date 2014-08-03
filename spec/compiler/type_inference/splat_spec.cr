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
end
