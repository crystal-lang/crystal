require "../../spec_helper"

describe "Code gen: named args" do
  it "calls with named arg" do
    expect(run(%(
      def foo(y = 2)
        y
      end

      foo y: 10
      )).to_i).to eq(10)
  end

  it "calls with named arg and other args" do
    expect(run(%(
      def foo(x, y = 2, z = 3)
        x + y + z
      end

      foo 1, z: 10
      )).to_i).to eq(13)
  end

  it "calls with named arg as object method" do
    expect(run(%(
      class Foo
        def foo(x, y = 2, z = 3)
          x + y + z
        end
      end

      Foo.new.foo 1, z: 10
      )).to_i).to eq(13)
  end

  it "calls twice with different types" do
    expect(run(%(
      def add(x, y = 1)
        x + y
      end

      value = 0
      value += add(1, y: 2)
      value += add(1, y: 1.3)
      value.to_i
      )).to_i).to eq(5)
  end

  it "calls new with named arg" do
    expect(run(%(
      class Foo
        def initialize(x, y = 2, z = 3)
          @value = x + y + z
        end

        def value
          @value
        end
      end

      Foo.new(1, z: 10).value
      )).to_i).to eq(13)
  end

  it "uses named args in dispatch" do
    expect(run(%(
      class Foo
        def foo(x, z = 2)
          x + z + 1
        end
      end

      class Bar
        def foo(x, z = 2)
          x + z
        end
      end

      a = Foo.new || Bar.new
      a.foo 1, z: 20
      )).to_i).to eq(22)
  end
end
