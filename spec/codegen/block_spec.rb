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
        yield
        x = 1
      end

      foo(1) { 1 }
      )).to_i.should eq(1)
  end

  it "can use global constant" do
    run(%q(
      FOO = 1
      def foo
        yield
        FOO
      end
      foo { }
    )).to_i.should eq(1)
  end

  it "return from yielder function" do
    run(%q(
      def foo
        yield
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

  it "return from yielder function (2)" do
    run(%q(
      def foo
        yield
        return 1 if true
        return 2
      end

      def bar
        foo {}
      end

      bar
    )).to_i.should eq(1)
  end

  it "union value of yielder function" do
    run(%q(
      def foo
        yield
        a = 1.1
        a = 1
        a
      end

      foo {}.to_i
    )).to_i.should eq(1)
  end

  it "allow return from function called from yielder function" do
    run(%q(
      def foo
        return 2
      end

      def bar
        yield
        foo
        1
      end

      bar {}
    )).to_i.should eq(1)
  end

  it "" do
    run(%q(
      def foo
        yield
        true ? return 1 : return 1.1
      end

      foo {}.to_i
    )).to_i.should eq(1)
  end

  it "return from block that always returns from function that always yields inside if block" do
    run(%q(
      def bar
        yield
        2
      end

      def foo
        if true
          bar { return 1 }
        else
          0
        end
      end

      foo
    )).to_i.should eq(1)
  end

  it "return from block that always returns from function that conditionally yields" do
    run(%q(
      def bar
        if true
          yield
        end
      end

      def foo
        bar { return 1 }
        2
      end

      foo
    )).to_i.should eq(1)
  end

  it "call block from dispatch" do
    run(%q(
      def bar(y)
        yield y
      end

      def foo
        x = 1.1
        x = 1
        bar(x) { |z| z }
      end

      foo.to_i
    )).to_i.should eq(1)
  end

  it "call block from dispatch and use local vars" do
    run(%q(
      def bar(y)
        yield y
      end

      def foo
        total = 0
        x = 1.5
        bar(x) { |z| total += z }
        x = 1
        bar(x) { |z| total += z }
        x = 1.5
        bar(x) { |z| total += z }
        total
      end

      foo.to_i
    )).to_i.should eq(4)
  end

  it "break without value returns nil" do
    run(%q(
      require "nil"

      def foo
        yield
        1
      end

      x = foo do
        break if true
      end

      x.nil?
    )).to_b.should be_true
  end

  it "break block with yielder inside while" do
    run(%q(
      require "int"
      a = 0
      10.times do
        a += 1
        break if a > 5
      end
      a
    )).to_i.should eq(6)
  end

  it "break from block returns from yielder" do
    run(%q(
      def foo
        yield
        yield
      end

      a = 0
      foo { a += 1; break }
      a
    )).to_i.should eq(1)
  end

  it "break from block with value" do
    run(%q(
      require "nil"

      def foo
        while true
          yield
          a = 3
        end
      end

      foo do
        break 1
      end.to_i
    )).to_i.should eq(1)
  end

  it "break from block with value" do
    run(%q(
      require "nil"

      def foo
        while true
          yield
          a = 3
        end
      end

      def bar
        foo do
          return 1
        end
      end

      bar.to_i
    )).to_i.should eq(1)
  end

  it "doesn't codegen after while that always yields and breaks" do
    run(%q(
      def foo
        while true
          yield
        end
        1
      end

      foo do
        break 2
      end
    )).to_i.should eq(2)
  end

  it "break from block with value" do
    run(%q(
      require "int"
      10.times { break 20 }
    )).to_i.should eq(20)
  end

  it "doesn't codegen call if arg yields and always breaks" do
    run(%q(
      require "nil"

      def foo
        1 + yield
      end

      foo { break 2 }.to_i
    )).to_i.should eq(2)
  end

  it "codegens nested return" do
    run(%q(
      def bar
        yield
        a = 1
      end

      def foo
        bar { yield }
      end

      def z
        foo { return 2 }
      end

      z
    )).to_i.should eq(2)
  end
end
