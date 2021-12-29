require "../../spec_helper"

describe "Code gen: named args" do
  it "calls with named arg" do
    run(%(
      def foo(y = 2)
        y
      end

      foo y: 10
      )).to_i.should eq(10)
  end

  it "calls with named arg and other args" do
    run(%(
      def foo(x, y = 2, z = 3)
        x &+ y &+ z
      end

      foo 1, z: 10
      )).to_i.should eq(13)
  end

  it "calls with named arg as object method" do
    run(%(
      class Foo
        def foo(x, y = 2, z = 3)
          x &+ y &+ z
        end
      end

      Foo.new.foo 1, z: 10
      )).to_i.should eq(13)
  end

  it "calls twice with different types" do
    run(%(
      struct Int32
        def &+(other : Float)
          self + other
        end
      end

      def add(x, y = 1)
        x &+ y
      end

      value = 0
      value &+= add(1, y: 2)
      value &+= add(1, y: 1.3)
      value.to_i!
      )).to_i.should eq(5)
  end

  it "calls new with named arg" do
    run(%(
      class Foo
        @value : Int32

        def initialize(x, y = 2, z = 3)
          @value = x &+ y &+ z
        end

        def value
          @value
        end
      end

      Foo.new(1, z: 10).value
      )).to_i.should eq(13)
  end

  it "uses named args in dispatch" do
    run(%(
      class Foo
        def foo(x, z = 2)
          x &+ z &+ 1
        end
      end

      class Bar
        def foo(x, z = 2)
          x &+ z
        end
      end

      a = Foo.new || Bar.new
      a.foo 1, z: 20
      )).to_i.should eq(22)
  end

  it "sends one regular argument as named argument" do
    run(%(
      def foo(x)
        x
      end

      foo x: 42
      )).to_i.should eq(42)
  end

  it "sends two regular arguments as named arguments" do
    run(%(
      def foo(x, y)
        x &+ y
      end

      foo x: 10, y: 32
      )).to_i.should eq(42)
  end

  it "sends two regular arguments as named arguments in inverted position (1)" do
    run(%(
      def foo(x, y)
        x
      end

      foo y: 42, x: "foo"
      )).to_string.should eq("foo")
  end

  it "sends two regular arguments as named arguments in inverted position (2)" do
    run(%(
      def foo(x, y)
        y
      end

      foo y: 42, x: "foo"
      )).to_i.should eq(42)
  end

  it "overloads based on required named args" do
    run(%(
      def foo(x, *, y)
        x &+ y
      end

      def foo(x, *, z)
        x &* z
      end

      a = foo(10, y: 20)
      b = foo(30, z: 40)
      a &+ b
      )).to_i.should eq(10 + 20 + 30*40)
  end

  it "overloads based on required named args, with restrictions" do
    run(%(
      def foo(x, *, z : Int32)
        x &+ z
      end

      def foo(x, *, z : Float64)
        x &* z.to_i!
      end

      a = foo(10, z: 20)
      b = foo(30, z: 40.0)
      a &+ b
      )).to_i.should eq(10 + 20 + 30*40)
  end

  it "uses bare splat in new (2)" do
    run(%(
      class Foo
        def initialize(*, y = 22)
          @y = y
        end

        def y
          @y
        end
      end

      v1 = Foo.new.y
      v2 = Foo.new(y: 20).y
      v1 &+ v2
      )).to_i.should eq(42)
  end
end
