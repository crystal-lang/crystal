require 'spec_helper'

describe 'Code gen: block' do
  it "generate inline" do
    run(%q(
      def foo
        yield
      end

      foo do
        1
      end
    )).to_i.should eq(1)
  end

  it "pass yield arguments" do
    run(%q(
      def foo
        yield 1
      end

      foo do |x|
        x + 1
      end
    )).to_i.should eq(2)
  end

  it "pass arguments to yielder function" do
    run(%q(
      def foo(a)
        yield a
      end

      foo(3) do |x|
        x + 1
      end
    )).to_i.should eq(4)
  end

  it "pass self to yielder function" do
    run(%q(
      class Int
        def foo
          yield self
        end
      end

      3.foo do |x|
        x + 1
      end
    )).to_i.should eq(4)
  end

  it "pass self and arguments to yielder function" do
    run(%q(
      class Int
        def foo(i)
          yield self, i
        end
      end

      3.foo(2) do |x, i|
        x + i
      end
    )).to_i.should eq(5)
  end

  it "allows access to local variables" do
    run(%q(
      def foo
        yield
      end

      x = 1
      foo do
        x + 1
      end
    )).to_i.should eq(2)
  end

  it "can access instance vars from yielder function" do
    run(%q(
      class Foo
        def initialize
          @x = 1
        end
        def foo
          yield @x
        end
      end

      Foo.new.foo do |x|
        x + 1
      end
    )).to_i.should eq(2)
  end

  it "can set instance vars from yielder function" do
    run(%q(
      class Foo
        def foo
          @x = yield
        end
        def value
          @x
        end
      end

      a = Foo.new
      a.foo { 2 }
      a.value
    )).to_i.should eq(2)
  end

  it "can use instance methods from yielder function" do
    run(%q(
      class Foo
        def foo
          yield value
        end
        def value
          1
        end
      end

      Foo.new.foo { |x| x + 1 }
    )).to_i.should eq(2)
  end

  it "can call methods from block when yielder is an instance method" do
    run(%q(
      class Foo
        def foo
          yield
        end
      end

      def bar
        1
      end

      Foo.new.foo { bar }
    )).to_i.should eq(1)
  end

  it "nested yields" do
    run(%q(
      def bar
        yield
      end

      def foo
        bar { yield }
      end

      a = foo { 1 }
    )).to_i.should eq(1)
  end

  it "assigns yield to argument" do
    run(%q(
      def foo(x)
        x = 1
      end

      foo(1) { 1 }
      )).to_i.should eq(1)
  end

  it "can use global constant" do
    run(%q(
      FOO = 1
      def foo
        FOO
      end
      foo { }
    )).to_i.should eq(1)
  end

  it "return from yielder function" do
    run(%q(
      def foo
        return 1
      end

      foo { }
      2
    )).to_i.should eq(2)
  end

  it "return from block" do
    run(%q(
      def foo
        yield
      end

      def bar
        foo { return 1 }
        2
      end

      bar
    )).to_i.should eq(1)
  end
end
