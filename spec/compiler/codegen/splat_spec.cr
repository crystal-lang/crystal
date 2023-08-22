require "../../spec_helper"

describe "Code gen: splat" do
  it "splats" do
    run(%(
      struct Tuple
        def size; {{T.size}}; end
      end

      def foo(*args)
        args.size
      end

      foo 1, 1, 1
      )).to_i.should eq(3)
  end

  it "splats with another arg" do
    run(%(
      struct Tuple
        def size; {{T.size}}; end
      end

      def foo(x, *args)
        x &+ args.size
      end

      foo 10, 1, 1
      )).to_i.should eq(12)
  end

  it "splats on call" do
    run(%(
      def foo(x, y)
        x &+ y
      end

      tuple = {1, 2}
      foo *tuple
      )).to_i.should eq(3)
  end

  it "splats without args" do
    run(%(
      struct Tuple
        def size; {{T.size}}; end
      end

      def foo(*args)
        args.size
      end

      foo
      )).to_i.should eq(0)
  end

  it "splats with default value" do
    run(%(
      struct Tuple
        def size; {{T.size}}; end
      end

      def foo(x = 100, *args)
        x &+ args.size
      end

      foo
      )).to_i.should eq(100)
  end

  it "splats with default value (2)" do
    run(%(
      struct Tuple
        def size; {{T.size}}; end
      end

      def foo(x, y = 100, *args)
        x &+ y &+ args.size
      end

      foo 10
      )).to_i.should eq(110)
  end

  it "splats with default value (3)" do
    run(%(
      struct Tuple
        def size; {{T.size}}; end
      end

      def foo(x, y = 100, *args)
        x &+ y &+ args.size
      end

      foo 10, 20, 30, 40
      )).to_i.should eq(32)
  end

  it "splats in initialize" do
    run(%(
      class Foo
        @x : Int32
        @y : Int32

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
      foo.x &+ foo.y
      )).to_i.should eq(3)
  end

  it "does #2407" do
    codegen(%(
      lib LibC
        fun exit(Int32) : NoReturn
      end

      def some
        yield(1 || (LibC.exit(1); ""))
      end

      def foo(*objects)
        bar *objects
      end

      def bar(objects)
      end

      some do |value|
        foo value
      end
      ))
  end

  it "evaluates splat argument just once (#2677)" do
    run(%(
      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      def data
        Global.x &+= 1
        {Global.x, Global.x, Global.x}
      end

      def test(x, y, z)
        x &+ y &+ z
      end

      v = test(*data)

      Global.x
      )).to_i.should eq(1)
  end
end
