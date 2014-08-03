#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Code gen: splat" do
  it "splats" do
    run(%(
      def foo(*args)
        args.length
      end

      foo 1, 1, 1
      )).to_i.should eq(3)
  end

  it "splats with another arg" do
    run(%(
      def foo(x, *args)
        x + args.length
      end

      foo 10, 1, 1
      )).to_i.should eq(12)
  end

  it "splats with two other args" do
    run(%(
      def foo(x, *args, z)
        x + args.length + z
      end

      foo 10, 2, 20
      )).to_i.should eq(31)
  end

  it "splats on call" do
    run(%(
      def foo(x, y)
        x + y
      end

      tuple = {1, 2}
      foo *tuple
      )).to_i.should eq(3)
  end

  it "splats without args" do
    run(%(
      def foo(*args)
        args.length
      end

      foo
      )).to_i.should eq(0)
  end
end
