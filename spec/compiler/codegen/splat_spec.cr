require "../../spec_helper"

describe "Code gen: splat" do
  it "splats" do
    expect(run(%(
      struct Tuple
        def length; {{@length}}; end
      end

      def foo(*args)
        args.length
      end

      foo 1, 1, 1
      )).to_i).to eq(3)
  end

  it "splats with another arg" do
    expect(run(%(
      struct Tuple
        def length; {{@length}}; end
      end

      def foo(x, *args)
        x + args.length
      end

      foo 10, 1, 1
      )).to_i).to eq(12)
  end

  it "splats with two other args" do
    expect(run(%(
      struct Tuple
        def length; {{@length}}; end
      end

      def foo(x, *args, z)
        x + args.length + z
      end

      foo 10, 2, 20
      )).to_i).to eq(31)
  end

  it "splats on call" do
    expect(run(%(
      def foo(x, y)
        x + y
      end

      tuple = {1, 2}
      foo *tuple
      )).to_i).to eq(3)
  end

  it "splats without args" do
    expect(run(%(
      struct Tuple
        def length; {{@length}}; end
      end

      def foo(*args)
        args.length
      end

      foo
      )).to_i).to eq(0)
  end

  it "splats with default value" do
    expect(run(%(
      struct Tuple
        def length; {{@length}}; end
      end

      def foo(x = 100, *args)
        x + args.length
      end

      foo
      )).to_i).to eq(100)
  end

  it "splats with default value (2)" do
    expect(run(%(
      struct Tuple
        def length; {{@length}}; end
      end

      def foo(x, y = 100, *args)
        x + y + args.length
      end

      foo 10
      )).to_i).to eq(110)
  end

  it "splats with default value (3)" do
    expect(run(%(
      struct Tuple
        def length; {{@length}}; end
      end

      def foo(x, y = 100, *args)
        x + y + args.length
      end

      foo 10, 20, 30, 40
      )).to_i).to eq(32)
  end

  it "splats in initialize" do
    expect(run(%(
      class Foo
        def initialize(*args)
          @x, @y = args
        end

        def x
          @x
        end

        def y
          @y
        end
      end

      foo = Foo.new 1, 2
      foo.x + foo.y
      )).to_i).to eq(3)
  end
end
